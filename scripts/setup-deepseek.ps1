# setup-deepseek.ps1
# Registers the DeepSeek Anthropic-compatible endpoint with cc-switch and tests
# connectivity. The API key itself is written to ~/.claude/settings.json by
# setup-hooks.ps1 (never stored in this repository).
[CmdletBinding()]
param(
    [string]$ApiKey = $env:DS_DEPLOY_DEEPSEEK_KEY,
    [string]$BaseUrl = 'https://api.deepseek.com/anthropic',
    [string]$Model = 'deepseek-flash'
)

$ErrorActionPreference = 'Stop'
$env:DS_DEPLOY_DEEPSEEK_KEY = $ApiKey

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw 'DeepSeek API key is required. Pass -ApiKey or set DS_DEPLOY_DEEPSEEK_KEY.'
}

# --- connectivity check -----------------------------------------------------
Write-Host '[deepseek] checking API connectivity...' -ForegroundColor Cyan
try {
    $headers = @{
        'Authorization'     = "Bearer $ApiKey"
        'anthropic-version' = '2023-06-01'
        'content-type'      = 'application/json'
    }
    $body = @{
        model      = $Model
        max_tokens = 8
        messages   = @(@{ role = 'user'; content = 'ping' })
    } | ConvertTo-Json -Depth 5 -Compress
    $resp = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/v1/messages') -Method Post `
        -Headers $headers -Body $body -TimeoutSec 45
    if ($resp.content) {
        Write-Host '[deepseek] API responded OK' -ForegroundColor Green
    } else {
        Write-Host '[deepseek] API responded but returned no content (check model name).' -ForegroundColor Yellow
    }
} catch {
    Write-Host "[deepseek] connectivity check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host '[deepseek] continuing anyway; settings will still be written.' -ForegroundColor Yellow
}

# --- register provider with cc-switch (optional convenience) ------------------
$cc = Join-Path $env:LOCALAPPDATA 'Programs\cc-switch-cli\cc-switch.exe'
if (-not (Test-Path -LiteralPath $cc)) {
    $ccCmd = Get-Command cc-switch -ErrorAction SilentlyContinue
    if ($ccCmd) { $cc = $ccCmd.Source }
}

if (Test-Path -LiteralPath $cc) {
    $list = ''
    try { $list = (& $cc provider list --app claude 2>&1 | Out-String) } catch { }
    if ($list -notmatch '(?m)^.*\bdeepseek\b') {
        Write-Host '[deepseek] registering provider in cc-switch...' -ForegroundColor Cyan
        & $cc provider add --app claude --template deepseek --id deepseek --name 'DeepSeek' `
            --base-url $BaseUrl --api-key $ApiKey `
            --haiku-model $Model --sonnet-model $Model --opus-model $Model `
            --fable-model $Model --subagent-model $Model 2>&1 | Out-Host
    } else {
        Write-Host '[deepseek] cc-switch already has a DeepSeek provider (not modified).' -ForegroundColor Green
    }
    Write-Host '[deepseek] note: the live endpoint comes from ~/.claude/settings.json env.' -ForegroundColor DarkGray
    Write-Host '[deepseek] cc-switch is optional; use "cc-switch provider list" to inspect it.' -ForegroundColor DarkGray
} else {
    Write-Host '[deepseek] cc-switch not found; skipping provider registration.' -ForegroundColor Yellow
}
