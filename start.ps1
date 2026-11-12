#Requires -Version 5.1
<#
.SYNOPSIS
    One-click start for the QQ / WeChat bridge.

.DESCRIPTION
    Checks the installation, starts (or restarts) the cc-connect daemon and
    prints its status. If cc-connect or the config is missing, it hands over to
    deploy.ps1 first.

.EXAMPLE
    .\start.ps1
    .\start.ps1 -OpenClaude
#>
[CmdletBinding()]
param(
    [switch]$OpenClaude,
    [string]$ConfigPath = (Join-Path $env:USERPROFILE '.cc-connect\config.toml')
)

$ErrorActionPreference = 'Stop'
try {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
} catch { }

$bin = Join-Path $env:USERPROFILE '.local\bin\cc-connect.exe'
$needDeploy = $false
if (-not (Test-Path -LiteralPath $bin)) {
    $cmd = Get-Command cc-connect -ErrorAction SilentlyContinue
    if ($cmd) { $bin = $cmd.Source } else { $needDeploy = $true }
}
if (-not (Test-Path -LiteralPath $ConfigPath)) { $needDeploy = $true }

if ($needDeploy) {
    Write-Host '[start] cc-connect or config.toml is missing, running deploy.ps1...' -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'deploy.ps1') -ConfigPath $ConfigPath
}

if (-not (Test-Path -LiteralPath $bin)) {
    throw 'cc-connect.exe still not found after deploy.'
}

$status = ''
try { $status = (& $bin daemon status 2>&1 | Out-String) } catch { $status = '' }

if ($status -match 'Status:\s*Running') {
    Write-Host '[start] daemon already running' -ForegroundColor Green
} else {
    Write-Host '[start] starting daemon...' -ForegroundColor Cyan
    & $bin daemon start 2>&1 | Out-Host
    Start-Sleep -Seconds 2
    $status = (& $bin daemon status 2>&1 | Out-String)
    if ($status -notmatch 'Status:\s*Running') {
        Write-Host '[start] daemon not running yet, installing the service...' -ForegroundColor Yellow
        & $bin daemon install --config $ConfigPath --work-dir (Split-Path -Parent $ConfigPath) 2>&1 | Out-Host
        Start-Sleep -Seconds 2
    }
}

& $bin daemon status 2>&1 | Out-Host

if ($OpenClaude) {
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) {
        Push-Location $env:USERPROFILE
        try { & $claude.Source } finally { Pop-Location }
    } else {
        Write-Host '[start] claude.exe not found; run deploy.ps1 first.' -ForegroundColor Yellow
    }
}
