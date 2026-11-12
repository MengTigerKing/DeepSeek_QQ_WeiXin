# setup-hooks.ps1
# Merges the DeepSeek env block and the camera approval hook into
# ~/.claude/settings.json. Existing settings and existing hooks are preserved;
# a timestamped backup is written before every change.
[CmdletBinding()]
param(
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json'),
    [string]$TemplatePath,
    [string]$ApiKey = $env:DS_DEPLOY_DEEPSEEK_KEY
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($TemplatePath)) { $TemplatePath = Join-Path $PSScriptRoot '..\config\settings.template.json' }

function Set-JsonProp($obj, [string]$name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

$homeFwd = $env:USERPROFILE.Replace('\', '/')
$templateText = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
$templateText = $templateText.Replace('{{HOME_FWD}}', $homeFwd)
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $templateText = $templateText.Replace('{{DEEPSEEK_API_KEY}}', '__SET_ME__')
} else {
    # JSON-escape the key before substitution.
    $escaped = $ApiKey.Replace('\', '\\').Replace('"', '\"')
    $templateText = $templateText.Replace('{{DEEPSEEK_API_KEY}}', $escaped)
}
$template = $templateText | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SettingsPath) | Out-Null
$existing = $null
if (Test-Path -LiteralPath $SettingsPath) {
    $raw = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $existing = $raw | ConvertFrom-Json }
        catch { throw "Existing settings.json is not valid JSON; refusing to overwrite. $($_.Exception.Message)" }
        $backup = $SettingsPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        Copy-Item -LiteralPath $SettingsPath -Destination $backup -Force
        Write-Host "[settings] backup: $backup" -ForegroundColor DarkGray
    }
}
if (-not $existing) { $existing = [pscustomobject]@{} }

# --- env ---------------------------------------------------------------------
if (-not $existing.PSObject.Properties['env']) {
    $existing | Add-Member -NotePropertyName 'env' -NotePropertyValue ([pscustomobject]@{})
}
foreach ($p in $template.env.PSObject.Properties) {
    $has = $existing.env.PSObject.Properties[$p.Name]
    $isToken = ($p.Name -eq 'ANTHROPIC_AUTH_TOKEN')
    if (-not $has) {
        Set-JsonProp $existing.env $p.Name $p.Value
    } elseif ($isToken -and -not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $existing.env.ANTHROPIC_AUTH_TOKEN = $ApiKey
    }
}

# --- simple top-level settings ----------------------------------------------
foreach ($name in @('modelSettings', 'autoUpdatesChannel', 'theme', 'model')) {
    if (-not $existing.PSObject.Properties[$name]) {
        Set-JsonProp $existing $name $template.$name
    }
}

# --- camera approval hook (PreToolUse) ---------------------------------------
if (-not $existing.PSObject.Properties['hooks']) {
    $existing | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([pscustomobject]@{})
}
$pre = @()
if ($existing.hooks.PSObject.Properties['PreToolUse']) { $pre = @($existing.hooks.PreToolUse) }
$hasCamera = $false
foreach ($group in $pre) {
    foreach ($h in @($group.hooks)) {
        if ($h.command -and ($h.command -match 'camera-ask-hook\.ps1')) { $hasCamera = $true }
    }
}
if (-not $hasCamera) {
    $newGroups = @($template.hooks.PreToolUse)
    $pre = $pre + $newGroups
    Set-JsonProp $existing.hooks 'PreToolUse' $pre
    Write-Host '[settings] camera approval hook added' -ForegroundColor Green
} else {
    Write-Host '[settings] camera approval hook already present' -ForegroundColor Green
}

# Never touched here: Stop hooks (the sticker feature is not part of this package).

$json = $existing | ConvertTo-Json -Depth 30
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($SettingsPath, $json, $utf8)

# Validate the result.
try { $null = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { throw "settings.json was written but does not parse: $($_.Exception.Message)" }

Write-Host "[settings] written: $SettingsPath" -ForegroundColor Green
