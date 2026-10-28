<p align="center">
  <img src="https://raw.githubusercontent.com/lannerk/frey-releases/main/assets/frey-logo-dark-color-256.png" alt="Frey" width="128">
</p>

<h1 align="center">Frey</h1>

<p align="center">
  用 Rust 写的 LLM agent harness：一个开箱即用的终端 coding agent（<code>frey</code>），和它底下可嵌入的运行时（<code>frey-core</code>）。<br>
  <sub>An LLM agent harness in Rust — a terminal coding agent plus the embeddable runtime underneath it.</sub>
</p>

<p align="center">
  <a href="https://github.com/lannerk/frey-releases/releases/latest"><img alt="release" src="https://img.shields.io/github/v/release/lannerk/frey-releases?filter=v*&label=frey&color=8E39D0"></a>
  <a href="https://github.com/lannerk/frey-releases/releases"><img alt="downloads" src="https://img.shields.io/github/downloads/lannerk/frey-releases/total?color=3066CF"></a>
  <img alt="platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-27A57F">
  <a href="EULA.md"><img alt="license" src="https://img.shields.io/badge/license-EULA-lightgrey"></a>
</p>

> 这是 Frey 的**发行仓**：下载、更新清单、版本说明和问题反馈都在这里。源码不公开（`frey-core` 计划开源，到时另有仓库）。
> 出品：innocraft.ai（元枢造物）。

## 目录

- [Frey 是什么](#frey-是什么)
- [下载](#下载)
- [安装](#安装)
- [快速开始](#快速开始)
- [使用教程](#使用教程)
- [Demo](#demo)
- [更新](#更新)
- [校验下载](#校验下载)
- [Frey Core](#frey-core)
- [Frey Craft](#frey-craft)
- [版本与发布日期](#版本与发布日期)
- [反馈](#反馈)
- [许可](#许可)

## Frey 是什么

Frey 把模型、工具、会话状态、权限策略、上下文压缩串成一个完整的 agent 循环：

- **`frey`** —— 终端里的 coding agent。读代码、改文件、跑命令；每一步按你设的权限模式决定要不要先问你。
- **`frey-core`** —— 上面那个循环本身，作为 Rust 库单独使用。模型、工具、审批、权限、会话存储、压缩、hooks 七个部件都是 trait，换任何一个都不用动循环。
- **`frey rpc`** —— 常驻的 stdio JSONL 双向通道，给编辑器、桌面端、别的程序把 Frey 当后端用。

| | |
|---|---|
| **多家模型，一处配置** | 内置 18 条厂商预设、13 家（DeepSeek、OpenRouter、Ollama、Anthropic、OpenAI、Gemini、xAI、Mistral、通义千问、Kimi、智谱、MiniMax、硅基流动）；写一行 `provider.vendor` 就能用，不在表里的填地址自动识别协议 |
| **协议** | Anthropic Messages、OpenAI Chat Completions、OpenAI Responses、Gemini 原生 |
| **七个内置工具** | `read_file` `write_file` `edit_file` `glob_search` `grep_search` `list_dir` `run_shell` |
| **权限引擎** | 四种模式、allow / deny 规则、受保护路径，外加任何模式都放不开的硬性拒绝；每次放行或拒绝都记下是谁定的 |
| **会话** | 只追加的 JSONL；`--resume latest` 接着聊；被强杀后续接会自动补上中断的工具结果 |
| **插话** | 回复进行中直接打字：排队、或在下一个安全边界插入，不丢任务 |
| **密钥不外泄** | key 只从环境变量读；`run_shell` 与 git 子进程看不到任何名字像密钥的变量 |
| **三平台原生** | Windows 10 1809+ / 11、Linux x86_64 / aarch64（glibc 2.28 及以上：RHEL / Rocky 8、Debian 10、Ubuntu 20.04 起）、macOS 13+（Apple Silicon 与 Intel）；单文件、无依赖，HTTPS 用 rustls |

## 下载

最新版在 [Releases](https://github.com/lannerk/frey-releases/releases/latest)。按平台挑一个：

| 平台 | 文件 |
|---|---|
| Windows x64 | `frey-<版本>-windows-x86_64.zip` |
| Linux x64 | `frey-<版本>-linux-x86_64.tar.gz` |
| Linux ARM64 | `frey-<版本>-linux-aarch64.tar.gz` |
| macOS Apple Silicon | `frey-<版本>-macos-aarch64.tar.gz` |
| macOS Intel | `frey-<版本>-macos-x86_64.tar.gz` |

每个包里只有四样：`frey`（Windows 是 `frey.exe`）、`VERSION`、`EULA.md`、`THIRD-PARTY-NOTICES`（所用开源组件的许可证与版权声明）。
机器可读的「最新版是哪个、哪天发的、每个平台的下载地址和校验值」在 [`manifests/frey.json`](manifests/frey.json)。

## 安装

### Windows

```powershell
# 1. 解压，把 frey.exe 放到一个在 PATH 里的目录，例如：
New-Item -ItemType Directory -Force "$env:USERPROFILE\bin" | Out-Null
Expand-Archive .\frey-*-windows-x86_64.zip -DestinationPath "$env:USERPROFILE\bin" -Force

# 2. 第一次要把这个目录加进 PATH（只需一次，重开终端生效）：
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\bin", "User")

# 3. 验证
frey --version
```

> SmartScreen 弹「Windows 已保护你的电脑」时点「更多信息 → 仍要运行」。Frey 目前没有买代码签名证书；下载是否被改过，请按 [校验下载](#校验下载) 核签名。
> 推荐用 Windows Terminal；旧的 conhost 控制台会自动降到基本模式。

### Linux

要求 glibc 2.28 及以上（RHEL / Rocky / AlmaLinux 8、Debian 10、Ubuntu 20.04 及以后；`ldd --version` 看版本）。

```bash
tar -xzf frey-*-linux-x86_64.tar.gz
install -m 755 frey ~/.local/bin/frey        # 或 sudo install -m 755 frey /usr/local/bin/frey
frey --version
```

### macOS

```bash
tar -xzf frey-*-macos-aarch64.tar.gz          # Intel 机器换 macos-x86_64
xattr -d com.apple.quarantine frey            # 还没有 Apple 公证，去掉隔离标记才能直接运行
install -m 755 frey ~/.local/bin/frey
frey --version
```

### 从源码

源码仓不公开；`frey-core` 开源后这里会补上 `cargo install` 的方式。

## 快速开始

1. 准备一个模型 key，**只放环境变量**（Frey 不读写死在文件里的 key）：

   ```bash
   export DEEPSEEK_API_KEY=sk-...            # PowerShell: $env:DEEPSEEK_API_KEY = "sk-..."
   ```

2. 告诉 Frey 用哪家：写 `~/.frey/config.toml`（Windows：`%USERPROFILE%\.frey\config.toml`）

   ```toml
   [provider]
   vendor = "deepseek"            # 预设会填好协议、地址、key 变量名
   ```

   别家要写模型名，例如 OpenRouter：

   ```toml
   [provider]
   vendor = "openrouter"
   model = "cohere/north-mini-code:free"     # key 放在 OPENROUTER_API_KEY
   ```

   本机 Ollama：`vendor = "ollama"`，`model = "qwen2.5-coder"`，不用 key。

3. 到你的项目目录里启动：

   ```bash
   cd your-project
   frey
   ```

不想先配 key、只想看看界面：`frey --tui-demo`（假回复，不联网）。

## 使用教程

### 交互模式 `frey`

全屏终端界面。直接打字派活；agent 要写文件或跑命令时，按权限模式决定是否先弹审批框。

| 按键 | 作用 |
|---|---|
| Enter | 发送（回复进行中按 Enter → 排队，等这轮结束再说） |
| Shift+Tab（可配） | **插话**：在下一个安全边界把这句插进去，正在跑的工具会被停掉、没跑的记「用户插话、未执行」，任务不丢 |
| Ctrl+J / Alt+Enter | 换行 |
| Esc / Ctrl+C | 打断当前回复；空闲时 Ctrl+C 退出 |
| Ctrl+D | 空行时退出 |
| PgUp / PgDn | 翻转录 |

| 命令 | 作用 |
|---|---|
| `/help` | 列出命令和按键 |
| `/add-dir <path>` | 本会话加一个工作区根目录 |
| `/compact` | 立刻把到目前为止的对话压缩成摘要 |
| `/update` | 检查并安装新版本（同 `frey update`） |
| `/exit` | 退出 |

在一个有中断会话的目录里启动时，Frey 会先问要不要接上（24 小时内、上次没正常结束的会话）。

### 一次性模式 `frey prompt`

跑一轮就退出，适合脚本与 CI。回复在 stdout，进度在 stderr：

```bash
frey prompt "把 README 里的错别字改掉"
echo "总结一下 src/ 的结构" | frey prompt
frey prompt --format json "跑一下测试并报告结果" > events.jsonl    # 每个事件一行 JSON
frey prompt --resume latest "继续"                                  # 接着本目录最近的会话
```

### 权限模式 `--mode`

| 模式 | 含义 |
|---|---|
| `read-only` | 只读工具直接跑；写文件、跑命令都先问 |
| `workspace-write`（默认） | 工作区里读写直接跑；跑命令、碰工作区外的路径先问 |
| `danger-full-access` | 命令也直接跑；写受保护路径（如 `~/.frey/`）仍要问 |
| `auto-allow` | 都不问；deny 规则与硬性拒绝照常生效 |

项目里放一份 `<项目>/.frey/config.toml` 只能**收紧**，不能放宽、不能改 `provider.*`——clone 下来的仓库改不了你的模型与权限。

### 常用参数

| 参数 | 作用 |
|---|---|
| `--model <MODEL>` | 覆盖配置里的模型 |
| `--profile <NAME>` | 内置 `coding`、`minimal`，或 `~/.frey/profiles/<NAME>.toml` |
| `--add-dir <PATH>` | 加一个工作区根（可重复） |
| `--resume <ID\|latest>` | 接着一个会话 |
| `--event-log <FILE>` | 交互模式下也把全部事件写成 JSONL |
| `--no-animation` / `--mouse` | 关掉加载动画 / 让滚轮翻转录 |

### 模型列表 `frey models`

```bash
frey models                               # 当前配置那家的模型
frey models --vendor openrouter --refresh
```

### 作为后端 `frey rpc`

```bash
frey rpc        # stdin / stdout 一行一个 JSON：hello → session.start → 事件流；审批、插话、宿主代理模型都走这条线
```

协议说明随版本附在 Release 页；版本号在 `frey --version` 的 `rpc` 一栏。

### 配置与环境变量

| 文件 | 作用 |
|---|---|
| `~/.frey/config.toml` | 用户配置：模型、权限、工具、压缩、更新 |
| `~/.frey/profiles/<名>.toml` | 一组可切换的设置 |
| `<项目>/.frey/config.toml` | 项目配置，只能收紧 |
| `AGENTS.md` 等指令文件 | 自动发现并放进 system prompt |
| `~/.frey/sessions/<id>.jsonl` | 会话，只追加，只给本人读 |

| 环境变量 | 作用 |
|---|---|
| 配置里 `provider.api_key_env` 指的那个 | API key（预设各有默认名，如 `DEEPSEEK_API_KEY`） |
| `NO_COLOR` | 不着色 |
| `FREY_THEME=light` | 浅色终端配色 |
| `FREY_TUI_BASIC=0\|1` | 强制关 / 开基本模式 |

## Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/lannerk/frey-releases/main/assets/demo-tui.png" alt="Frey 终端界面" width="760">
</p>

一轮工具往返（`frey prompt`，真模型）：

```console
$ cat app.toml
version = 1
name = "demo"

$ frey prompt --mode auto-allow 'Read app.toml, change version to 2 with edit_file, then run: echo done'
frey: provider: DeepSeek (openai_compat, https://api.deepseek.com; provider.vendor)
frey: tool: read_file
frey: tool: edit_file
frey: tool: run_shell
Done — app.toml now has version = 2, and `echo done` printed "done".

$ cat app.toml
version = 2
name = "demo"
```

## 更新

```bash
frey update --check     # 本地版本与日期、最新版本与日期、本平台有没有包
frey update             # 下载 → 核 SHA-256 与签名 → 原子替换自己 → 重启生效
frey update --rollback  # 换回上一版
```

- 交互模式启动后会在后台查一次（状态行提示「有 0.9.3」，不打扰）；不想要就在配置里写 `[update] check_on_start = false`。
- 更新只认这个仓库里的 [`manifests/frey.json`](manifests/frey.json) 和编进程序里的公钥，**不接受**环境变量或配置里的替代地址——改不了，也就劫持不了。
- 签名不过，程序不换，旧版原地不动。
- 装在没写权限的目录（如 `/usr/local/bin`）时不自动替换，会打印下载好的路径让你自己 `sudo install`。

## 校验下载

每个 Release 带 `SHA256SUMS` 和 [minisign](https://jedisct1.github.io/minisign/) 签名（`*.minisig`）。公钥在 [`keys/frey.pub`](keys/frey.pub)：

```bash
sha256sum -c SHA256SUMS --ignore-missing
minisign -Vm frey-0.9.3-linux-x86_64.tar.gz -p keys/frey.pub
```

Windows 上 `Get-FileHash .\frey-0.9.3-windows-x86_64.zip` 对照 `SHA256SUMS` 即可；minisign 的 Windows 版在它的 Release 页。

## Frey Core

`frey-core` 是 Frey 的运行时库，与 `frey` 同版本号、同一天发。它计划开源（到时另有源码仓，并发布到 crates.io）；在那之前这里只提供它的版本与发布日期：[`manifests/frey-core.json`](manifests/frey-core.json)。

`frey --version` 会一并打印 core 的版本和三个契约版本（事件线 `protocol`、会话文件 `session`、`rpc`）——接 Frey 的程序据此判断要不要升级。

## Frey Craft

Frey 的桌面端（Rust + Tauri），在 Frey 本身完成后开工。到时安装包（Windows `setup.exe` / `.msi`、macOS `.dmg`、Linux `.AppImage` / `.deb`）也发在本仓库，tag 以 `craft-v` 开头，更新清单在 `manifests/frey-craft.json`，应用内「关于 → 检查更新」自动走它。

## 版本与发布日期

- 第一个版本是 **0.9.1**，之后每版只加末位（0.9.2、0.9.3 …… 0.9.12 ……），正式版才是 1.0.0。
- 每个版本都有发布日期（Asia/Shanghai），`frey --version` 带出来：`frey 0.9.2 (2026-10-26) x86_64-pc-windows-msvc`。
- 已发布的版本**不会被覆盖或删除**；有问题就发下一版。
- 每版的变更写在该版本的 Release 说明里。

## 反馈

- bug、建议、问题：开 [Issue](https://github.com/lannerk/frey-releases/issues)。请附 `frey --version` 的输出和复现步骤；**不要贴 key、会话文件或含路径的截图**。
- 安全问题请不要开公开 Issue，发邮件到 lannerk@qq.com。

## 许可

Frey、Frey Core、Frey Craft 是闭源软件，按 [EULA](EULA.md) 授权使用：

- **预览版（1.0 之前，含 0.9.x）**：免费评估，**有使用期限**，到期后请更新到新的预览版（`frey update`）。到期日在 `frey --version` 和启动提示里显示。
- **正式版（1.0 起）**：订阅付费使用。订阅方式、价格与试用安排在正式版发布前公布。
- 不授予源码；禁止反编译、再分发、转售。`frey-core` 将来若开源，以其源码仓的许可证为准。
- 第三方开源组件的声明见随包分发的 `THIRD-PARTY-NOTICES`。
