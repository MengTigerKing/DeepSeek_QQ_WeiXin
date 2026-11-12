# install-cc-switch.ps1
# Installs the cc-switch command-line tool (SaladDay/cc-switch-cli) on Windows.
# The desktop app and the CLI are different products; this package uses the CLI
# for provider switching: https://github.com/SaladDay/cc-switch-cli
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\cc-switch-cli'),
    [string]$Mirror = 'https://ghfast.top/'
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $InstallDir 'cc-switch.exe'

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

if (Test-Path -LiteralPath $exe) {
    Write-Host "[cc-switch] already installed: $exe" -ForegroundColor Green
    & $exe --version
    exit 0
}

Write-Host '[cc-switch] downloading cc-switch-cli (Windows x64)...' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$tmpRoot = Join-Path $env:TEMP ('cc-switch-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$zip = Join-Path $tmpRoot 'cc-switch-cli.zip'

$urls = @(
    ($Mirror + 'https://github.com/SaladDay/cc-switch-cli/releases/latest/download/cc-switch-cli-windows-x64.zip'),
    'https://github.com/SaladDay/cc-switch-cli/releases/latest/download/cc-switch-cli-windows-x64.zip'
)
$downloaded = $false
foreach ($u in $urls) {
    try {
        Write-Host "  GET $u"
        Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 300
        if ((Get-Item $zip).Length -gt 100KB) { $downloaded = $true; break }
    } catch {
        Write-Host "  failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
if (-not $downloaded) {
    throw 'Could not download cc-switch-cli. Download cc-switch-cli-windows-x64.zip manually from https://github.com/SaladDay/cc-switch-cli/releases and extract cc-switch.exe next to this script.'
}

Expand-Archive -LiteralPath $zip -DestinationPath $tmpRoot -Force
$found = Get-ChildItem -Path $tmpRoot -Recurse -Filter 'cc-switch*.exe' |
    Where-Object { $_.Name -ne 'cc-switch-cli-setup.exe' } |
    Select-Object -First 1
if (-not $found) {
    throw 'cc-switch.exe was not found inside the downloaded archive.'
}
Copy-Item -LiteralPath $found.FullName -Destination $exe -Force
Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

Add-UserPath $InstallDir
Write-Host "[cc-switch] installed: $exe" -ForegroundColor Green
& $exe --version
