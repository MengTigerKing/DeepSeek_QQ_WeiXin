#Requires -Version 5.1
<#
.SYNOPSIS
    Packages the live configuration into a timestamped ZIP.

.DESCRIPTION
    Includes the cc-connect config, Claude Code settings, the camera hook and
    the assistant memory files (optionally the cc-switch data directory).
    The archive contains credentials: keep it private, never commit or share it.

.EXAMPLE
    .\backup.ps1
    .\backup.ps1 -IncludeCcSwitch
    .\backup.ps1 -OutputDir D:\somewhere\safe
#>
[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$IncludeCcSwitch
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $PSScriptRoot 'backups' }
$homeDir = $env:USERPROFILE
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $env:TEMP ('cc-backup-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Copy-IfExists([string]$src, [string]$dstRel) {
    if (-not (Test-Path -LiteralPath $src)) { return $false }
    $dst = Join-Path $stage $dstRel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    return $true
}

$included = @()
$ccConfig = Join-Path $homeDir '.cc-connect\config.toml'
if (Copy-IfExists $ccConfig '.cc-connect\config.toml') { $included += '.cc-connect\config.toml' }

$settings = Join-Path $homeDir '.claude\settings.json'
if (Copy-IfExists $settings '.claude\settings.json') { $included += '.claude\settings.json' }

$cameraHook = Join-Path $homeDir 'camera-ask-hook.ps1'
if (Copy-IfExists $cameraHook 'camera-ask-hook.ps1') { $included += 'camera-ask-hook.ps1' }

$proj = $homeDir.Replace(':', '-').Replace('\', '-')
$memDir = Join-Path $homeDir ".claude\projects\$proj\memory"
if (Copy-IfExists $memDir ('.claude\projects\' + $proj + '\memory')) {
    $included += ".claude\projects\$proj\memory\*"
}

if ($IncludeCcSwitch) {
    $ccSwitchDir = Join-Path $homeDir '.cc-switch'
    if (Copy-IfExists $ccSwitchDir '.cc-switch') { $included += '.cc-switch\*' }
}

# --- manifest ---------------------------------------------------------------
$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add('cc-connect / Claude Code / DeepSeek bridge - live configuration backup')
$manifest.Add("created   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$manifest.Add("computer  : $env:COMPUTERNAME")
$manifest.Add("user      : $env:USERNAME")
$manifest.Add('')
$manifest.Add('included  :')
foreach ($i in $included) { $manifest.Add("  - $i") }
$manifest.Add('')
$manifest.Add('versions  :')

$bin = Join-Path $homeDir '.local\bin\cc-connect.exe'
if (Test-Path -LiteralPath $bin) {
    $manifest.Add('  cc-connect: ' + (((& $bin --version) 2>&1 | Select-Object -First 1)))
}
$claude = Join-Path $homeDir '.local\bin\claude.exe'
if (-not (Test-Path -LiteralPath $claude)) {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { $claude = $c.Source }
}
if (Test-Path -LiteralPath $claude) {
    $manifest.Add('  claude    : ' + (((& $claude --version) 2>&1 | Select-Object -First 1)))
}
$ccSwitch = Join-Path $env:LOCALAPPDATA 'Programs\cc-switch-cli\cc-switch.exe'
if (Test-Path -LiteralPath $ccSwitch) {
    $manifest.Add('  cc-switch : ' + (((& $ccSwitch --version) 2>&1 | Select-Object -First 1)))
}
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg) {
    $manifest.Add('  ffmpeg    : ' + (((& $ffmpeg.Source -version) 2>&1 | Select-Object -First 1)))
}
$manifest.Add('')
$manifest.Add('WARNING: this archive contains API keys and bot secrets. Keep it private.')
[IO.File]::WriteAllLines((Join-Path $stage 'MANIFEST.txt'), $manifest, (New-Object System.Text.UTF8Encoding($false)))

# --- zip --------------------------------------------------------------------
$zip = Join-Path $OutputDir "cc-bridge-backup-$stamp.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

$size = (Get-Item $zip).Length
Write-Host "[backup] created: $zip" -ForegroundColor Green
Write-Host ("[backup] size   : {0:N0} KB" -f ($size / 1KB))
Write-Host '[backup] WARNING: contains credentials - do not share or commit.' -ForegroundColor Yellow
