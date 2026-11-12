# camera-ask-hook.ps1 - PreToolUse(Bash) guard
# Any camera-related shell command must go through an explicit approval prompt,
# even when the agent would otherwise auto-approve it.
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }
if ($j.tool_name -ne 'Bash') { exit 0 }
$cmd = [string]$j.tool_input.command
if ($cmd -match '(?i)camera|webcam|dshow|MediaCapture|CameraCaptureUI|windows\.camera') {
  $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = 'Camera/device access requires explicit approval from the owner.' } }
  $out | ConvertTo-Json -Compress -Depth 5
}
exit 0
