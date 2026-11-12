# DeepSeek + Claude Code + QQ / 微信 一键部署

把 **Claude Code** 接到 **DeepSeek 的 Anthropic 兼容接口**，再通过
[cc-connect](https://github.com/chenhg5/cc-connect) 桥接到 **QQ 机器人** 和
**微信私聊**，在一台 Windows 电脑上跑成常驻服务。所有步骤都脚本化，新机器上一条命令即可部署。

## 架构

```
 QQ 群 / 微信私聊
        │
        ▼
 cc-connect（后台守护进程）
   ├─ wechat  项目：只允许主人本人，工作目录 = 用户主目录
   └─ qq-chat 项目：群成员都能聊，敏感操作需要群里点“允许”
        │
        ▼
 Claude Code（本地 CLI，claude.exe）
        │  ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN
        ▼
 DeepSeek API（https://api.deepseek.com/anthropic）
```

辅助组件：

- **cc-switch CLI**：管理 Claude Code 的供应商（DeepSeek / 官方），可选。
- **camera-ask-hook.ps1**：任何摄像头命令强制弹出审批，不能自动放行。
- **ffmpeg**：摄像头录制（`-f dshow -i video="Integrated Camera"`）。

## 目录结构

```
DeepSeek_QQ_WeiXin/
├─ deploy.ps1                     # 一键部署入口
├─ start.ps1 / start.cmd          # 一键启动（双击 start.cmd 即可）
├─ stop.ps1                       # 一键停止
├─ backup.ps1                     # 把当前生效配置打包成 ZIP
├─ CONFIG-NOTES.md                # 2026-11-12/13 全部配置变更记录
├─ config/
│  ├─ config.example.toml         # cc-connect 配置模板（密钥已占位）
│  └─ settings.template.json      # Claude Code 设置模板（含 DeepSeek env）
├─ scripts/
│  ├─ install-claude-code.ps1
│  ├─ install-cc-switch.ps1
│  ├─ install-cc-connect.ps1
│  ├─ setup-deepseek.ps1
│  ├─ setup-hooks.ps1
│  ├─ setup-ffmpeg.ps1
│  ├─ camera-ask-hook.ps1
│  ├─ start-daemon.ps1
│  └─ verify.ps1
├─ memory/                        # 助手记忆文件（新机器首次部署时写入）
└─ bin/cc-connect.exe             # cc-connect v1.5.2-beta.1
```

## 前置条件

- Windows 10 / 11，PowerShell 5.1+
- 能访问 GitHub（脚本内置 `ghfast.top` 镜像回退）
- 需要准备：DeepSeek API Key、QQ 机器人 AppID/AppSecret、微信桥接的
  token / base_url / account_id、主人 QQ 号和 sender_id

## 一键部署

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy.ps1
```

脚本会按顺序执行并且可以重复运行；已存在的文件会先备份。缺少的参数会交互式询问。

只补装某一部分时用开关跳过其它步骤，例如只恢复脚本和 hook：

```powershell
.\deploy.ps1 -SkipClaude -SkipCcSwitch -SkipDeepSeek -SkipCcConnect `
             -SkipConfig -SkipFfmpeg -SkipMemory -SkipDaemon
```

常用参数：

| 参数 | 说明 |
| --- | --- |
| `-DeepSeekApiKey` | DeepSeek Key；不传则安全提示输入 |
| `-OwnerQQ` / `-OwnerSenderId` | 主人 QQ 号 / sender_id |
| `-OwnerWechatId` / `-WechatOpenId` | 主人微信号 / 微信 openid |
| `-WechatToken` / `-WechatBaseUrl` / `-WechatAccountId` | 微信桥接配置 |
| `-QqAppId` / `-QqAppSecret` | QQ 机器人配置 |
| `-ForceConfig` | 用模板重新生成 `config.toml` |
| `-SkipClaude` 等 | 跳过对应步骤 |

也可以用环境变量传参：`DEEPSEEK_API_KEY`、`DS_OWNER_QQ`、`DS_OWNER_SENDER_ID`、
`DS_WECHAT_TOKEN` 等（见 `deploy.ps1` 顶部）。

## 一键启动 / 停止

部署完成后，日常只需要：

```powershell
.\start.ps1          # 启动（已在运行则显示状态）
.\stop.ps1           # 停止
```

也可以直接双击 `start.cmd`。`start.ps1` 发现 cc-connect 或配置缺失时会自动转去执行
`deploy.ps1`；加 `-OpenClaude` 会在启动桥接后顺便打开 Claude Code。

## 一键备份

```powershell
.\backup.ps1                  # 备份到 .\backups\cc-bridge-backup-<时间>.zip
.\backup.ps1 -IncludeCcSwitch # 连 cc-switch 数据目录一起备份
```

备份内容：`~\.cc-connect\config.toml`、`~\.claude\settings.json`、
`camera-ask-hook.ps1`、助手记忆文件（可选 `~\.cc-switch\`）以及版本清单。
**压缩包内含密钥，已加入 `.gitignore`，不要提交或外传。**

## 部署脚本做了什么

| 步骤 | 脚本 | 结果 |
| --- | --- | --- |
| 1 | `install-claude-code.ps1` | 原生安装器 → winget → npm 三级回退，安装 `claude.exe` |
| 2 | `install-cc-switch.ps1` | 下载 cc-switch-cli 到 `%LOCALAPPDATA%\Programs\cc-switch-cli` |
| 3 | `setup-deepseek.ps1` | 测通 DeepSeek 接口，并在 cc-switch 里注册 provider |
| 4 | `install-cc-connect.ps1` | 复制自带 `cc-connect.exe` 到 `%USERPROFILE%\.local\bin` |
| 5 | `deploy.ps1` | 生成 `~\.cc-connect\config.toml`（已有则保留） |
| 6 | `setup-hooks.ps1` | 合并 DeepSeek env 与摄像头审批 hook 到 `~\.claude\settings.json` |
| 7 | `deploy.ps1` | 把 `memory/` 写入 Claude Code 项目记忆目录（不覆盖已有文件） |
| 8 | `setup-ffmpeg.ps1` | winget（可选）/ 镜像下载 + SHA256 校验安装 ffmpeg |
| 9 | `start-daemon.ps1` | 安装或重启 cc-connect 守护进程 |
| 10 | `verify.ps1` | 打印健康检查（不显示任何密钥） |

### 单独执行

```powershell
.\scripts\install-claude-code.ps1
.\scripts\setup-ffmpeg.ps1
.\scripts\start-daemon.ps1
.\scripts\verify.ps1
```

## 关键配置

### DeepSeek 接入

写入 `~\.claude\settings.json` 的 `env`：

```
ANTHROPIC_BASE_URL = https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN = <你的 Key>
ANTHROPIC_DEFAULT_{HAIKU,SONNET,OPUS,FABLE}_MODEL = deepseek-flash
CLAUDE_CODE_SUBAGENT_MODEL = deepseek-flash
```

`model` 设为 `haiku`，所有档位都映射到 `deepseek-flash`。

### 摄像头审批

`camera-ask-hook.ps1` 注册为 `PreToolUse(Bash)`，命中
`camera|webcam|dshow|MediaCapture|CameraCaptureUI|windows.camera` 时返回
`permissionDecision: ask`。即使 agent 本来能自动执行，也必须由人点“允许”。

录制示例：

```powershell
ffmpeg -hide_banner -f dshow -i "video=Integrated Camera" -t 3 `
  -c:v libx264 -preset veryfast -pix_fmt yuv420p -movflags +faststart -y out.mp4
```

### 称呼与权限

- QQ 号 `{{OWNER_QQ}}`（sender_id `{{OWNER_SENDER_ID}}`）称为“主人”，只有该
  sender_id 使用恭敬语气；其他人正常称呼。
- 微信项目只有主人本人可用，同样称“主人”。
- 群成员可以请求读写文件/执行命令，但每次工具调用都走平台审批，由主人点“允许”。

## 密钥与隐私

- **`config.toml` 不进仓库**：`config/` 里只有占位符模板。
- **DeepSeek Key 不落盘到仓库**：部署时写入 `~\.claude\settings.json`。
- `.gitignore` 已排除 `config/config.toml`、`*.bak-*`、日志等。
- 群聊回复只回“已发送”，不暴露路径、文件名、数量。

## 常见问题

**claude.ai 安装脚本 302 到不可用地区页**
脚本会自动回退到 winget（`Anthropic.ClaudeCode`）→ npm。都失败时从
<https://claude.com/claude-code> 手动安装。

**winget 下载超时（Delivery Optimization）**
ffmpeg 脚本默认走 `ghfast.top` 镜像 + 官方 winget manifest 的 SHA256 校验；
只有加 `-TryWingetFirst` 才先试 winget。

**改完称呼/提示词没生效**
cc-connect 会复用旧会话，旧会话保留旧系统提示。停掉守护进程，把
`~\.cc-connect\sessions\qq-chat_*.json` 移到备份目录，再启动即可。

**QQ 群主动发消息报 40034105**
群机器人默认不能在回复窗口外主动推送。需要群主在 QQ 开放平台开启“主动推送消息”
能力；否则只能等用户先说话。私聊（C2C）同样可能受限。

**D 盘路径审批失败（permission stream closed）**
把操作写进主目录的 `.ps1`，再用 `powershell -NoProfile -File .\x.ps1` 执行，
命令行里不要出现 D 盘路径。

**摄像头被占用 / IR 摄像头**
用 `Integrated Camera`，不要用 `Integrated IR Camera`。先关闭正在使用摄像头的应用。

## 本包未包含

- 表情包发送功能（`qq-sticker*.ps1` 与对应 Stop hook）。按主人要求本次不打包；
  如需恢复，可另行加回脚本并注册 Stop hook。
- 企业微信项目：原配置中已注释停用，模板里保留为注释示例。

## 版本

- cc-connect v1.5.2-beta.1（`bin/cc-connect.exe`）
- Claude Code 2.1.x（原生安装）
- cc-switch-cli（SaladDay/cc-switch-cli 最新版）
- ffmpeg 9.0.2 full build（Gyan.dev，SHA256 校验）

详见 [CONFIG-NOTES.md](CONFIG-NOTES.md)。
