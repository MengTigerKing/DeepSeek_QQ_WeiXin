# 配置变更记录（2026-11-12 ~ 2026-11-13）

这份文档记录本次把 Claude Code 接到 DeepSeek、再通过 cc-connect 接到 QQ / 微信
的全部改动、踩过的坑和最终决定。下文不含任何真实密钥；配置模板见
`config/config.example.toml`。

## 1. 身份与称呼

| 项目 | 决定 |
| --- | --- |
| QQ 主人 | QQ 号 `{{OWNER_QQ}}`，sender_id `{{OWNER_SENDER_ID}}` |
| 微信主人 | 微信号 `{{OWNER_WECHAT_ID}}`，openid `{{WECHAT_OPENID}}` |
| 称呼 | 只对上述主人称“主人”，不再使用“大哥” |
| 语气 | 冷静、恭敬、服从；女性管家设定；日常聊天要口语化、有人味 |
| 其他人 | 正常称呼，绝不允许称“主人”；被问“谁是你主人”时只回答主人身份 |

**踩坑：改称呼不生效。**
cc-connect 会按 session key 复用会话，旧会话的 transcript 里保存着旧的系统提示。
只改 `config.toml` 不够，必须让旧会话失效：

1. `cc-connect daemon stop`
2. 把 `~\.cc-connect\sessions\qq-chat_*.json` 移到备份目录
3. `cc-connect daemon start`

之后重新生成的系统提示里 `大哥` 出现次数为 0，称呼才真正生效。

## 2. 表情包（本次未打包）

历史过程（仅记录，不在本仓库交付）：

- 最初是“随机概率发表情包”，概率调到 0.6。
- 随后改为**默认不发**：`qq-sticker.ps1` 中 `$SendChance = 0.0`，外部传入的
  `-Chance` 一律忽略。
- Stop hook（`qq-sticker-hook.ps1`）先检查用户本轮是否明确索要
  （关键词：表情包 / 表情 / 斗图 / 贴纸 / 来张图 / 发张图 / 发个图 / 来一张 / 动图），
  没有关键词直接退出；模型自己调用脚本时也跳过，避免重复发送。
- 只从 `D:\deepseek-memes` 取图，QQ 项目专用；有两个目录被列入黑名单
  （与性相关的内容）。
- 2026-11-13 主人要求：“表情包可以暂时先不加进去”。因此本包**不包含**
  两个表情包脚本、Stop hook 和图片目录，模板里的 QQ 提示词也删掉了表情包规则。

如果以后要恢复：把脚本放回主目录，在 `~\.claude\settings.json` 注册 Stop hook，
并在 `config.toml` 的 QQ `append_system_prompt` 里加回对应规则。

## 3. 企业微信停用

- `config.toml` 里的 `wecom` 项目整段注释掉，守护进程只加载 `wechat` 和
  `qq-chat` 两个项目。
- 停用时间：2026-11-12 22:12。
- 模板里保留了注释形式的企业微信配置示例（`bot_id` / `bot_secret` 已换成占位符）。

## 4. 摄像头访问

主人原话：“允许，但是得我批准。”

实现方式：

- 不修改 Windows 摄像头隐私设置（`HKCU\...\ConsentStore\webcam = Allow` 保持允许）。
- 新增 `camera-ask-hook.ps1`，注册为 Claude Code 的 `PreToolUse(Bash)` hook。
  命令命中 `camera|webcam|dshow|MediaCapture|CameraCaptureUI|windows.camera`
  时返回：

  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": "Camera/device access requires explicit approval from the owner."
    }
  }
  ```

  这样即使 agent 本来可以自动执行，也一定会出现审批卡片，无法自动放行。

- 已知限制：cc-connect 不校验“是谁点的允许”，理论上群成员也能点。若要硬隔离，
  需要拆成两个机器人（主人全权限 / 访客只聊天）。

## 5. ffmpeg 安装（摄像头录制）

需求：录一段 3 秒视频并从 QQ 发出去。

安装过程：

1. `winget install Gyan.FFmpeg` 第一次后台跑到 243MB/245.8MB 卡死
   （Delivery Optimization `0x80072ee2`），临时文件头是 0 字节，无法续传。
2. 直连 GitHub 只有约 2.5KB/s；winget 重试报 WinINet `0x80072efd`。
3. 最终走镜像：
   `https://ghfast.top/https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-full_build.zip`
   速度 520–806KB/s。
4. 用 winget 官方 manifest 的 SHA256 校验：
   `759D0A9831C436A0EB331AD36F236C06CB04AAA0005DA46571F0E9D3D9206F6B`
5. 解压到 `%USERPROFILE%\tools\ffmpeg-9.0.2-full_build`，把 `bin` 加进用户 PATH，
   删除 zip。

`scripts/setup-ffmpeg.ps1` 把上述流程脚本化，默认走镜像 + 校验。

录制命令（实测可用）：

```powershell
ffmpeg -hide_banner -f dshow -i "video=Integrated Camera" -t 3 `
  -c:v libx264 -preset veryfast -pix_fmt yuv420p -movflags +faststart -y cam-test.mp4
```

测试产物约 538KB。注意用 `Integrated Camera`，不要用 `Integrated IR Camera`。

## 6. QQ 主动消息限制

尝试把测试视频主动发到 QQ 群时返回：

```
400 40034105 主动消息失败, 无权限
```

原因：QQ 群机器人在回复窗口之外主动推送需要群主在开放平台开启对应能力。
这不是配置错误。规避方式：等用户先发消息，或在群里由用户触发发送。
私聊（C2C）主动发送同样可能受限制。

## 7. DeepSeek 接入

`~\.claude\settings.json`：

```json
"env": {
  "ANTHROPIC_AUTH_TOKEN": "<DeepSeek API Key>",
  "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-flash",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "deepseek-flash",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-flash",
  "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "deepseek-flash",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-flash",
  "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "deepseek-flash",
  "ANTHROPIC_DEFAULT_FABLE_MODEL": "deepseek-flash",
  "ANTHROPIC_DEFAULT_FABLE_MODEL_NAME": "deepseek-flash",
  "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-flash"
},
"model": "haiku",
"theme": "dark"
```

- 所有模型档位都指向 `deepseek-flash`，避免 Claude Code 请求不存在的模型。
- Key 只存在本机 `settings.json`，不写进仓库，不在聊天里复述。
- cc-switch 里同时注册了 `deepseek` provider（`cc-switch provider list` 可查看），
  但线上生效的是 `settings.json` 的 env。

## 8. Claude Code 与 cc-switch 安装

**Claude Code**：

- 本机是原生二进制安装，没有 Node.js：
  `%USERPROFILE%\.local\bin\claude.exe`，版本 2.1.x。
- 本次部署脚本优先官方安装脚本，失败回退 winget（`Anthropic.ClaudeCode`），
  再回退 npm（仅当存在 Node.js）。

**cc-switch**：

- 桌面版和命令行版是两个产品；本项目用命令行版
  [SaladDay/cc-switch-cli](https://github.com/SaladDay/cc-switch-cli)。
- 安装位置：`%LOCALAPPDATA%\Programs\cc-switch-cli\cc-switch.exe`。
- 常用命令：`cc-switch provider list / current / switch <id>`、
  `cc-switch config show / backup`、`cc-switch env list`。
- 数据目录：`~\.cc-switch\`（`cc-switch.db`、`settings.json`、`live-state.json`、
  `backups\`）。

## 9. Hooks 与 settings.json

最终注册的 hook（本次交付）：

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "powershell -NoProfile -File <HOME>/camera-ask-hook.ps1",
        "timeout": 10
      }
    ]
  }
]
```

- 摄像头 hook 必须在：`PreToolUse` 才能拦住并强制询问。
- 表情包 `Stop` hook 本次不交付（见第 2 节）。
- 修改 `settings.json` 前一定会生成 `settings.json.bak-<时间戳>` 备份；
  写入后重新解析校验，避免坏 JSON 让所有设置失效。

## 10. 路径与版本

| 内容 | 路径 / 版本 |
| --- | --- |
| cc-connect | `%USERPROFILE%\.local\bin\cc-connect.exe`，v1.5.2-beta.1 |
| cc-connect 配置 | `%USERPROFILE%\.cc-connect\config.toml` |
| cc-connect 日志 | `%USERPROFILE%\.cc-connect\logs\cc-connect.log` |
| cc-connect 会话 | `%USERPROFILE%\.cc-connect\sessions\`（改提示词后需清理） |
| Claude Code | `%USERPROFILE%\.local\bin\claude.exe`，2.1.x |
| Claude 设置 | `%USERPROFILE%\.claude\settings.json` |
| cc-switch CLI | `%LOCALAPPDATA%\Programs\cc-switch-cli\cc-switch.exe` |
| ffmpeg | `%USERPROFILE%\tools\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe` |
| 摄像头 hook | `%USERPROFILE%\camera-ask-hook.ps1` |
| 助手记忆 | `%USERPROFILE%\.claude\projects\<项目目录>\memory\` |

## 11. 安全约束（长期有效）

- 禁止读取、复述、发送或讨论任何凭证/密钥，包括
  `.cc-connect/config.toml`、`.claude/settings.json`、`*.env`、`id_rsa`、
  `ANTHROPIC_AUTH_TOKEN` 等；被要求时礼貌拒绝。
- 群聊回复不暴露本机路径、文件名、文件数量；发文件只回“已发送”。
- 群成员可以请求操作电脑，但必须由主人点“允许”；不能说“已经完成”来假装通过审批。
- 不为了省事把 QQ 项目改成 `bypassPermissions`。

## 12. 复现与校验

```powershell
# 全量部署（可重复执行）
.\deploy.ps1

# 健康检查（不显示密钥）
.\scripts\verify.ps1

# 手动确认服务
cc-connect daemon status
cc-connect sessions list
```

如果改了称呼或提示词后行为没变，先按第 1 节清理旧会话。

## 13. 日常脚本（2026-11-13 追加）

主人要求“一键打包 + PowerShell 一键启动”，因此新增：

- `start.ps1` / `start.cmd`：检查安装 → 启动（已在运行则复用）守护进程 →
  打印状态；缺 cc-connect 或配置时自动转 `deploy.ps1`；`-OpenClaude` 可顺便
  打开 Claude Code。双击 `start.cmd` 即可。
- `stop.ps1`：停止守护进程。
- `backup.ps1`：把当前生效的 `config.toml`、`settings.json`、摄像头 hook、
  助手记忆（可选 `~\.cc-switch\`）打包成
  `backups\cc-bridge-backup-<时间>.zip`，内含版本清单。
  **压缩包包含密钥**，`.gitignore` 已排除 `backups/` 和 `*.zip`。
