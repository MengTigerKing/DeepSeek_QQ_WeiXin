# install-claude-code.ps1
# Installs Claude Code on Windows without Node.js (native binary), falls back to
# winget, then to npm if a Node.js toolchain happens to exist.
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = $machine + ';' + $user
}

function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:USERPROFILE '.local\bin\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\claude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\claude.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

Refresh-Path
$existing = Find-Claude
if ($existing -and -not $Force) {
    Write-Host "[claude] already installed: $existing" -ForegroundColor Green
    & $existing --version
    exit 0
}

Write-Host '[claude] installing Claude Code (native installer)...' -ForegroundColor Cyan
$installed = $false

# 1) Official native installer. In some regions claude.ai returns 302 to an
#    "app-unavailable-in-region" page, hence the fallbacks below.
try {
    $script = (Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -UseBasicParsing -TimeoutSec 60).Content
    if ($script -match '\$ErrorActionPreference|param\s*\(') {
        Invoke-Expression $script
        Refresh-Path
        if (Find-Claude) { $installed = $true }
    }
} catch {
    Write-Host "[claude] official installer unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2) winget (source: winget community repo, id Anthropic.ClaudeCode)
if (-not $installed) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host '[claude] trying winget package Anthropic.ClaudeCode...' -ForegroundColor Cyan
        try {
            & winget install --id Anthropic.ClaudeCode --exact --silent `
                --accept-source-agreements --accept-package-agreements 2>&1 | Out-Host
            Refresh-Path
            if (Find-Claude) { $installed = $true }
        } catch {
            Write-Host "[claude] winget failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# 3) npm, only if Node.js is present
if (-not $installed) {
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) {
        Write-Host '[claude] trying npm install -g @anthropic-ai/claude-code...' -ForegroundColor Cyan
        try {
            & npm install -g '@anthropic-ai/claude-code' 2>&1 | Out-Host
            Refresh-Path
            if (Find-Claude) { $installed = $true }
        } catch {
            Write-Host "[claude] npm failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

$exe = Find-Claude
if (-not $exe) {
    throw 'Claude Code could not be installed automatically. Install it manually from https://claude.com/claude-code and re-run deploy.ps1.'
}

Write-Host "[claude] installed: $exe" -ForegroundColor Green
& $exe --version
