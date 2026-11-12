---
name: no-paths-in-group-chat
description: 群聊回复里不要暴露本机路径、目录名、文件名等细节，防止隐私泄露
metadata:
  node_type: memory
  type: feedback
  originSessionId: 62d47847-6f50-42fc-baf6-4b69ca88e439
  modified: 2026-11-12T13:43:17.446Z
---

主人要求：在群聊（QQ 群）回复中**不要说明具体细节**，例如本机路径（`D:\wallpaper`）、文件数量、具体文件名、脚本名等。

**Why:** 群里有其他人，路径和目录信息属于隐私，暴露后可能被利用（结合 [[owner-only-computer-access]] 的审批机制也存在被绕过的风险）。

**How to apply:** 发文件/图时消息正文只说"已发送"这类一句话，不列路径、不报文件名、不说目录里有多少东西、不提用了哪个脚本。需要这些细节时只主人私聊或他明确要求时给出。同理，参见 [[code-output-as-txt-file]]：发 txt 附件也只留简短说明。
