---
name: code-output-as-txt-file
description: 长代码/长文本不要直接发消息，写成 .txt 文件用 cc-connect send --file 发送
metadata:
  node_type: memory
  type: feedback
  originSessionId: 62d47847-6f50-42fc-baf6-4b69ca88e439
  modified: 2026-11-12T13:43:18.099Z
---

主人要求：需要返回代码（或较长内容）时，整理成代码块 **.txt 文档**，用 `cc-connect send --file` 发过去，而不是把大段内容直接贴在消息里。

**Why:** QQ 消息有长度限制，长代码贴进去会被截断或拆成多条；txt 附件不受这个限制。

**How to apply:** 生成文件放到家目录 `{{HOME}}\`（不要放 D 盘，见 [[out-of-home-disk-access]]），文件名用有意义的英文/拼音 slug + `.txt`，然后 `cc-connect send --file /absolute/path/xxx.txt`。消息正文只留一两句说明，不复述文件全文。短代码片段（几行以内）仍可直接写在消息里。
