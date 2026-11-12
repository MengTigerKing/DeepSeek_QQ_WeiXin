# verify.ps1
# Prints a health summary. It never prints API keys, tokens or config contents.
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
try {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
} catch { }
$ok = 0
$bad = 0

function Check([string]$name, [scriptblock]$probe) {
    try {
        $value = & $probe
        if ($value) {
            Write-Host ("  [OK]   {0,-12} {1}" -f $name, $value) -ForegroundColor Green
            $script:ok++
        } else {
            Write-Host ("  [--]   {0,-12} missing" -f $name) -ForegroundColor Yellow
            $script:bad++
        }
    } catch {
        Write-Host ("  [--]   {0,-12} missing" -f $name) -ForegroundColor Yellow
        $script:bad++
    }
}

Write-Host ''
Write-Host '=== Deployment health check ===' -ForegroundColor Cyan

Check 'claude' {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $c) { $c = Get-Item (Join-Path $env:USERPROFILE '.local\bin\claude.exe') -ErrorAction SilentlyContinue }
    if ($c) { (& $c.Source --version) 2>&1 | Select-Object -First 1 }
}

Check 'cc-switch' {
    $c = Join-Path $env:LOCALAPPDATA 'Programs\cc-switch-cli\cc-switch.exe'
    if (Test-Path -LiteralPath $c) { (& $c --version) 2>&1 | Select-Object -First 1 }
}

Check 'cc-connect' {
    $c = Join-Path $env:USERPROFILE '.local\bin\cc-connect.exe'
    if (Test-Path -LiteralPath $c) { ((& $c --version) 2>&1 | Select-Object -First 1) }
}

Check 'ffmpeg' {
    $c = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($c) { (& $c.Source -version) 2>&1 | Select-Object -First 1 }
}

Check 'daemon' {
    $c = Join-Path $env:USERPROFILE '.local\bin\cc-connect.exe'
    if (Test-Path -LiteralPath $c) {
        $s = (& $c daemon status) 2>&1 | Out-String
        if ($s -match 'Status:\s*(\w+)') { $matches[1] }
    }
}

Check 'config' {
    $p = Join-Path $env:USERPROFILE '.cc-connect\config.toml'
    if (Test-Path -LiteralPath $p) { '{0:N0} bytes' -f (Get-Item $p).Length }
}

Check 'settings' {
    $p = Join-Path $env:USERPROFILE '.claude\settings.json'
    if (Test-Path -LiteralPath $p) {
        $j = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
        $hooks = 0
        if ($j.hooks) {
            foreach ($evt in $j.hooks.PSObject.Properties) {
                $hooks += @($evt.Value).Count
            }
        }
        $hasKey = if ($j.env.ANTHROPIC_AUTH_TOKEN -and $j.env.ANTHROPIC_AUTH_TOKEN -ne '__SET_ME__') { 'token set' } else { 'TOKEN MISSING' }
        "hooks=$hooks, $hasKey"
    }
}

Check 'camera-hook' {
    $p = Join-Path $env:USERPROFILE 'camera-ask-hook.ps1'
    if (Test-Path -LiteralPath $p) { 'installed' }
}

Write-Host ''
Write-Host ("  {0} OK, {1} missing/unknown" -f $ok, $bad) -ForegroundColor Cyan
Write-Host ''
