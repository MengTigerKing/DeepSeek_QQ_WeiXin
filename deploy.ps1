#Requires -Version 5.1
<#
.SYNOPSIS
    One-click deployment for the DeepSeek + Claude Code + QQ/WeChat bridge
    (cc-connect) on Windows.

.DESCRIPTION
    Installs and configures, in order:
      1. Claude Code (native installer / winget / npm)
      2. cc-switch CLI
      3. DeepSeek Anthropic-compatible API (env in ~/.claude/settings.json)
      4. cc-connect (bundled binary) and its config.toml
      5. camera approval hook
      6. assistant memory files (optional)
      7. ffmpeg for camera capture (optional)
      8. the background daemon

    Every step is idempotent. Existing files are backed up, never silently
    replaced. API keys and bot secrets are never written into this repository.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy.ps1

.EXAMPLE
    # Restore only the scripts/hooks on a machine that already has config:
    .\deploy.ps1 -SkipClaude -SkipCcSwitch -SkipDeepSeek -SkipFfmpeg -SkipMemory -SkipDaemon
#>
[CmdletBinding()]
param(
    [string]$DeepSeekApiKey = $env:DEEPSEEK_API_KEY,
    [string]$OwnerQQ        = $env:DS_OWNER_QQ,
    [string]$OwnerSenderId  = $env:DS_OWNER_SENDER_ID,
    [string]$OwnerWechatId  = $env:DS_OWNER_WECHAT_ID,
    [string]$WechatToken    = $env:DS_WECHAT_TOKEN,
    [string]$WechatBaseUrl  = $env:DS_WECHAT_BASE_URL,
    [string]$WechatAccountId = $env:DS_WECHAT_ACCOUNT_ID,
    [string]$WechatOpenId   = $env:DS_WECHAT_OPENID,
    [string]$QqAppId        = $env:DS_QQ_APP_ID,
    [string]$QqAppSecret    = $env:DS_QQ_APP_SECRET,
    [string]$ConfigPath     = (Join-Path $env:USERPROFILE '.cc-connect\config.toml'),

    [switch]$SkipClaude,
    [switch]$SkipCcSwitch,
    [switch]$SkipDeepSeek,
    [switch]$SkipCcConnect,
    [switch]$SkipConfig,
    [switch]$SkipHooks,
    [switch]$SkipMemory,
    [switch]$SkipFfmpeg,
    [switch]$SkipDaemon,
    [switch]$ForceConfig
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$Root       = $PSScriptRoot
$ScriptsDir = Join-Path $Root 'scripts'
$ConfigDir  = Join-Path $Root 'config'
$HomeDir    = $env:USERPROFILE
$CcConfig   = $ConfigPath
$Settings   = Join-Path $HomeDir '.claude\settings.json'

$script:StepNo = 0
function Step([string]$title) {
    $script:StepNo++
    Write-Host ''
    Write-Host ("[{0}] {1}" -f $script:StepNo, $title) -ForegroundColor Cyan
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}
function Info([string]$msg) { Write-Host "    $msg" -ForegroundColor Gray }

function Escape-Toml([string]$s) {
    return $s.Replace('\', '\\').Replace('"', '\"')
}

function Read-Value([string]$label) {
    if (-not [Environment]::UserInteractive) {
        throw "Missing value '$label'. Re-run with the corresponding parameter."
    }
    $v = Read-Host "    $label"
    if ([string]::IsNullOrWhiteSpace($v)) { throw "Missing value '$label'." }
    return $v.Trim()
}

function Read-Secret([string]$label) {
    if (-not [Environment]::UserInteractive) {
        throw "Missing value '$label'. Re-run with the corresponding parameter."
    }
    $sec = Read-Host "    $label" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host ' DeepSeek + Claude Code + QQ / WeChat one-click deploy' -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White
Info "package : $Root"
Info "home    : $HomeDir"
Info "powershell: $($PSVersionTable.PSVersion)"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Info 'note: not running as administrator (fine for user-scope installs)'
}

# --- 1. Claude Code ----------------------------------------------------------
if ($SkipClaude) {
    Step 'Claude Code: skipped'
} else {
    Step 'Claude Code'
    & (Join-Path $ScriptsDir 'install-claude-code.ps1')
}

# --- 2. cc-switch CLI --------------------------------------------------------
if ($SkipCcSwitch) {
    Step 'cc-switch: skipped'
} else {
    Step 'cc-switch CLI'
    & (Join-Path $ScriptsDir 'install-cc-switch.ps1')
}

# --- 3. DeepSeek -------------------------------------------------------------
if ($SkipDeepSeek) {
    Step 'DeepSeek API: skipped'
} else {
    Step 'DeepSeek API'
    if ([string]::IsNullOrWhiteSpace($DeepSeekApiKey)) {
        $DeepSeekApiKey = Read-Secret 'DeepSeek API Key (sk-...)'
    }
    $env:DS_DEPLOY_DEEPSEEK_KEY = $DeepSeekApiKey
    & (Join-Path $ScriptsDir 'setup-deepseek.ps1')
}

# --- 4. cc-connect binary ----------------------------------------------------
if ($SkipCcConnect) {
    Step 'cc-connect: skipped'
} else {
    Step 'cc-connect'
    & (Join-Path $ScriptsDir 'install-cc-connect.ps1')
}

# --- 5. config.toml ----------------------------------------------------------
if ($SkipConfig) {
    Step 'cc-connect config: skipped'
} else {
    Step 'cc-connect config.toml'
    $needGenerate = (-not (Test-Path -LiteralPath $CcConfig)) -or $ForceConfig
    if (-not $needGenerate) {
        Info "existing config kept: $CcConfig"
        Info 'use -ForceConfig to regenerate it from the template'
    } else {
        $template = Get-Content -LiteralPath (Join-Path $ConfigDir 'config.example.toml') -Raw -Encoding UTF8
        $values = [ordered]@{
            '{{OWNER_QQ}}'          = $OwnerQQ
            '{{OWNER_SENDER_ID}}'   = $OwnerSenderId
            '{{OWNER_WECHAT_ID}}'   = $OwnerWechatId
            '{{WECHAT_TOKEN}}'      = $WechatToken
            '{{WECHAT_BASE_URL}}'   = $WechatBaseUrl
            '{{WECHAT_ACCOUNT_ID}}' = $WechatAccountId
            '{{WECHAT_OPENID}}'     = $WechatOpenId
            '{{QQ_APP_ID}}'         = $QqAppId
            '{{QQ_APP_SECRET}}'     = $QqAppSecret
        }
        $labels = @{
            '{{OWNER_QQ}}'          = 'Owner QQ number (e.g. 123456789)'
            '{{OWNER_SENDER_ID}}'   = 'Owner QQ sender_id (from a [cc-connect sender_id=...] prefix)'
            '{{OWNER_WECHAT_ID}}'   = 'Owner WeChat id (e.g. wxid_xxx)'
            '{{WECHAT_TOKEN}}'      = 'WeChat bridge token'
            '{{WECHAT_BASE_URL}}'   = 'WeChat bridge base URL'
            '{{WECHAT_ACCOUNT_ID}}' = 'WeChat bridge account id'
            '{{WECHAT_OPENID}}'     = 'WeChat openid allowed to talk to the bot'
            '{{QQ_APP_ID}}'         = 'QQ bot AppID'
            '{{QQ_APP_SECRET}}'     = 'QQ bot AppSecret'
        }
        foreach ($k in $values.Keys) {
            if ([string]::IsNullOrWhiteSpace($values[$k])) {
                $values[$k] = Read-Value $labels[$k]
            }
        }
        $text = $template
        foreach ($k in $values.Keys) {
            $text = $text.Replace($k, (Escape-Toml ([string]$values[$k])))
        }
        # HOME must be a TOML-escaped Windows path.
        $text = $text.Replace('{{HOME}}', (Escape-Toml $HomeDir))

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CcConfig) | Out-Null
        if (Test-Path -LiteralPath $CcConfig) {
            $bak = $CcConfig + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
            Copy-Item -LiteralPath $CcConfig -Destination $bak -Force
            Info "backup: $bak"
        }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($CcConfig, $text, $utf8)
        Info "written: $CcConfig"
    }
}

# --- 6. hooks + settings -----------------------------------------------------
if ($SkipHooks) {
    Step 'hooks/settings: skipped'
} else {
    Step 'camera hook + Claude settings'
    $hookSrc = Join-Path $ScriptsDir 'camera-ask-hook.ps1'
    $hookDst = Join-Path $HomeDir 'camera-ask-hook.ps1'
    if ((Test-Path -LiteralPath $hookDst) -and
        ((Get-FileHash $hookSrc).Hash -ne (Get-FileHash $hookDst).Hash)) {
        $bak = $hookDst + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        Copy-Item -LiteralPath $hookDst -Destination $bak -Force
        Info "backup: $bak"
    }
    Copy-Item -LiteralPath $hookSrc -Destination $hookDst -Force
    Info "hook: $hookDst"
    & (Join-Path $ScriptsDir 'setup-hooks.ps1') -SettingsPath $Settings -ApiKey $DeepSeekApiKey
}

# --- 7. memory ---------------------------------------------------------------
if ($SkipMemory) {
    Step 'memory files: skipped'
} else {
    Step 'assistant memory files'
    $srcMem = Join-Path $Root 'memory'
    if (Test-Path -LiteralPath $srcMem) {
        $proj = $HomeDir.Replace(':', '-').Replace('\', '-')
        $dstMem = Join-Path $HomeDir ".claude\projects\$proj\memory"
        New-Item -ItemType Directory -Force -Path $dstMem | Out-Null
        $map = @{
            '{{OWNER_QQ}}'        = $OwnerQQ
            '{{OWNER_SENDER_ID}}' = $OwnerSenderId
            '{{OWNER_WECHAT_ID}}' = $OwnerWechatId
            '{{HOME}}'            = $HomeDir
            '{{WINDOWS_USER}}'    = (Split-Path -Leaf $HomeDir)
        }
        foreach ($f in Get-ChildItem -LiteralPath $srcMem -Filter '*.md') {
            if ($f.Name -eq 'MEMORY.md') { continue }
            $destFile = Join-Path $dstMem $f.Name
            if (Test-Path -LiteralPath $destFile) {
                Info "memory: $($f.Name) (exists, kept)"
                continue
            }
            $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
            foreach ($k in $map.Keys) {
                if ($map[$k]) { $content = $content.Replace($k, $map[$k]) }
            }
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText($destFile, $content, $utf8)
            Info "memory: $($f.Name)"
        }
        # Merge the index, never overwrite the user's existing MEMORY.md.
        $srcIndex = Join-Path $srcMem 'MEMORY.md'
        $dstIndex = Join-Path $dstMem 'MEMORY.md'
        if (Test-Path -LiteralPath $srcIndex) {
            $lines = @(Get-Content -LiteralPath $srcIndex -Encoding UTF8)
            $current = @()
            if (Test-Path -LiteralPath $dstIndex) {
                $current = @(Get-Content -LiteralPath $dstIndex -Encoding UTF8)
            }
            $added = 0
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($current -notcontains $line) { $current += $line; $added++ }
            }
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText($dstIndex, (($current -join "`r`n") + "`r`n"), $utf8)
            Info "memory index: +$added line(s)"
        }
    } else {
        Info 'no memory folder in the package'
    }
}

# --- 8. ffmpeg ---------------------------------------------------------------
if ($SkipFfmpeg) {
    Step 'ffmpeg: skipped'
} else {
    Step 'ffmpeg (camera capture)'
    & (Join-Path $ScriptsDir 'setup-ffmpeg.ps1')
}

# --- 9. daemon ---------------------------------------------------------------
if ($SkipDaemon) {
    Step 'daemon: skipped'
} else {
    Step 'cc-connect daemon'
    & (Join-Path $ScriptsDir 'start-daemon.ps1') -ConfigPath $CcConfig
}

Remove-Item Env:DS_DEPLOY_DEEPSEEK_KEY -ErrorAction SilentlyContinue

# --- 10. verify --------------------------------------------------------------
Step 'verification'
& (Join-Path $ScriptsDir 'verify.ps1')

Write-Host 'Next steps' -ForegroundColor White
Info '1. Open WeChat / QQ and send a message to the bot.'
Info '2. If the bot repeats old wording, stop the daemon, move ~/.cc-connect/sessions/*.json'
Info '   to a backup folder, and start it again (old sessions keep the old system prompt).'
Info '3. Camera commands always raise an approval prompt (camera-ask-hook.ps1).'
Info '4. Sticker sending is intentionally not part of this package.'
Info '5. Day-to-day: run .\start.ps1 (or double-click start.cmd) to start, .\stop.ps1 to stop.'
Write-Host ''
