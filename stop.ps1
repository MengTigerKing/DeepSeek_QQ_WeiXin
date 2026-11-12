#Requires -Version 5.1
<#
.SYNOPSIS
    One-click stop for the QQ / WeChat bridge.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
} catch { }

$bin = Join-Path $env:USERPROFILE '.local\bin\cc-connect.exe'
if (-not (Test-Path -LiteralPath $bin)) {
    $cmd = Get-Command cc-connect -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'cc-connect.exe not found.' }
    $bin = $cmd.Source
}

Write-Host '[stop] stopping daemon...' -ForegroundColor Cyan
& $bin daemon stop 2>&1 | Out-Host
Start-Sleep -Seconds 1
& $bin daemon status 2>&1 | Out-Host
