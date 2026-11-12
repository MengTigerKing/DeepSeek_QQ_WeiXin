# start-daemon.ps1
# Installs (if needed) and starts the cc-connect background service, then
# restarts it if it is already running so config changes take effect.
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE '.cc-connect\config.toml')
)

$ErrorActionPreference = 'Stop'

$bin = Join-Path $env:USERPROFILE '.local\bin\cc-connect.exe'
if (-not (Test-Path -LiteralPath $bin)) {
    $cmd = Get-Command cc-connect -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'cc-connect.exe not found. Run install-cc-connect.ps1 first.' }
    $bin = $cmd.Source
}
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath. Run deploy.ps1 without -SkipConfig first."
}

$workDir = Split-Path -Parent $ConfigPath
$status = ''
try { $status = (& $bin daemon status 2>&1 | Out-String) } catch { $status = '' }

if ($status -match 'Status:\s*Running') {
    Write-Host '[daemon] running, restarting to apply config...' -ForegroundColor Cyan
    & $bin daemon restart --force 2>&1 | Out-Host
} else {
    Write-Host '[daemon] installing background service...' -ForegroundColor Cyan
    & $bin daemon install --config $ConfigPath --work-dir $workDir 2>&1 | Out-Host
}

Start-Sleep -Seconds 2
& $bin daemon status 2>&1 | Out-Host
