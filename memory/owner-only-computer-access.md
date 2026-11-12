---
name: owner-only-computer-access
description: "Computer access policy: WeChat owner-only; QQ group members may request file/command ops, but the owner is the designated approver (soft, not hard-enforced)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c9322cac-12c8-4673-9403-08f2a7745606
  modified: 2026-11-12T15:33:45.707Z
---

Policy as of 2026-11-12 (owner reverted the stricter variant with "不是，你先改回去吧"):

- **WeChat**: owner-only (`allow_from` = the owner's WeChat id), full access.
- **QQ group**: all members may chat and may *request* file reads/writes/commands; every tool call raises a permission prompt in the group, and the owner (QQ {{OWNER_QQ}}, sender_id `{{OWNER_SENDER_ID}}`) is the intended approver.
- **Camera (2026-11-12)**: explicitly allowed by the owner ("允许，但是得我批准"), NOT blocked at the OS level. A user-level `PreToolUse` hook on Bash (`{{HOME}}\camera-ask-hook.ps1`, registered in `~/.claude/settings.json`) matches camera/webcam/dshow/MediaCapture/CameraCaptureUI/windows.camera commands and returns `permissionDecision: ask`, so camera use always requires the approval card and can never be auto-approved. Same caveat as below: cc-connect doesn't verify who clicks 允许. **ffmpeg**: winget failed repeatedly (DO timeout 0x80072ee2, then WinINet 0x80072efd), so ffmpeg 9.0.2 full build was downloaded via the `ghfast.top` GitHub mirror and verified against the official winget manifest SHA256 (`759D0A…D9206F6B`); extracted to `{{HOME}}\tools\ffmpeg-9.0.2-full_build` (bin added to user PATH, verified `ffmpeg -version`). Use `-f dshow -i video="Integrated Camera"` for capture; the IR camera is not suitable for normal video.
- **Credentials**: never read or send `.cc-connect/config.toml`, `.claude/settings.json`, `*.env`, `id_rsa` etc. to anyone.

History: the owner toggled this several times on 2026-11-12 (owner-only → open → owner-approves → owner-only → back to owner-approves). Follow the latest instruction; when in doubt, ask.

**How to apply:** Do not claim hard enforcement. cc-connect embeds the requester's session key in the permission button and does not verify who clicks it, so any group member could technically approve. If the owner asks for airtight enforcement, propose the two-bot design (owner bot full access, guest bot chat-only). Never widen the WeChat project. See [[cc-connect-wechat-setup]].
