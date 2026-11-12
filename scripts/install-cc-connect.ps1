# install-cc-connect.ps1
# Installs the bundled cc-connect.exe into %USERPROFILE%\.local\bin and adds
# that directory to the user PATH.
[CmdletBinding()]
param(
    [string]$Source,
    [string]$InstallDir = (Join-Path $env:USERPROFILE '.local\bin')
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Source)) { $Source = Join-Path $PSScriptRoot '..\bin\cc-connect.exe' }
$Source = [IO.Path]::GetFullPath($Source)
if (-not (Test-Path -LiteralPath $Source)) {
    throw "Bundled binary not found: $Source"
}

function Add-UserPath([string]$dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($current -split ';' | Where-Object { $_ })
    if ($parts -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $dir) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $dir) {
        $env:Path = $env:Path + ';' + $dir
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$target = Join-Path $InstallDir 'cc-connect.exe'

if (Test-Path -LiteralPath $target) {
    $same = $false
    try {
        $same = ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq
                 (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash)
    } catch { }
    if ($same) {
        Add-UserPath $InstallDir
        Write-Host "[cc-connect] already installed (same binary): $target" -ForegroundColor Green
        & $target --version
        exit 0
    }
    # A running daemon keeps the exe locked; stop it before replacing.
    Write-Host '[cc-connect] replacing a different binary, stopping daemon first...' -ForegroundColor Yellow
    try { & $target daemon stop 2>&1 | Out-Null } catch { }
    Start-Sleep -Seconds 1
}

try {
    Copy-Item -LiteralPath $Source -Destination $target -Force
} catch {
    throw "Could not replace $target (is the daemon still running?). Stop it with start.ps1/stop.ps1 and re-run. $($_.Exception.Message)"
}
Add-UserPath $InstallDir

Write-Host "[cc-connect] installed: $target" -ForegroundColor Green
& $target --version
