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
| **密钥不外泄** | key 由 Frey 存在 `~/.frey/auth.toml`（只有你能读），不进会话与日志，文件工具读写不了它；`run_shell` 与 git 子进程看不到任何名字像密钥的变量 |
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

**一句命令装好，不要管理员**；装完新开一个终端，直接打 `frey`。

Windows（PowerShell）：

```powershell
irm https://raw.githubusercontent.com/lannerk/frey-releases/main/install.ps1 | iex
```

Linux / macOS（终端）：

```bash
curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/install.sh | sh
```

脚本做的事：从 [`manifests/frey.json`](manifests/frey.json) 找本平台的最新版 → 下载 → 核 SHA-256（对不上就停，机器上什么都不改）→ 放到 Windows 的 `%LOCALAPPDATA%\Programs\Frey\`、Linux / macOS 的 `~/.local/bin/` → 把这个目录加进**你自己的** PATH（Windows 写当前用户的环境变量；Linux / macOS 不在 PATH 里时往 shell 的启动文件加一行，带 `# added by frey installer` 标记）。**再跑一次就是升级。** 走系统或 `HTTPS_PROXY` 的代理。

装完运行 `frey`，第一次会弹设置面板选服务商、贴 key（见 [快速开始](#快速开始)）——安装脚本不碰 key。

<details>
<summary>指定版本或安装目录</summary>

```powershell
$env:FREY_VERSION = "0.9.2"; $env:FREY_INSTALL_DIR = "D:\tools\frey"
irm https://raw.githubusercontent.com/lannerk/frey-releases/main/install.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/install.sh | FREY_VERSION=0.9.2 FREY_INSTALL_DIR=~/bin sh
```

</details>

### 卸载

同样一句命令：

```powershell
irm https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.sh | sh
```

或者不联网：`frey uninstall`。删掉程序、安装时加的那条 PATH（只删它自己加的）和 `~/.frey/updates/`（更新留下的旧版）。`~/.frey` 里的 key、会话、配置**默认保留**，会问你一次要不要一起删；直接全删：`frey uninstall --purge`；用脚本时是 `curl -fsSL …/uninstall.sh | sh -s -- --purge`，PowerShell 里先 `$env:FREY_PURGE = "1"` 再跑那一句。

### 不用脚本，手动装

从 [下载](#下载) 拿包，按平台：

- **Windows**：解压后双击 `frey.exe`，选好项目目录和模型后，在 `/settings` 里选「Add frey to PATH for this user」，以后新开的终端里直接打 `frey`。
  > SmartScreen 弹「Windows 已保护你的电脑」时点「更多信息 → 仍要运行」。Frey 目前没有买代码签名证书；下载是否被改过，请按 [校验下载](#校验下载) 核签名。推荐用 Windows Terminal；旧的 conhost 控制台会自动降到基本模式。
- **Linux**（glibc 2.28 及以上：RHEL / Rocky / AlmaLinux 8、Debian 10、Ubuntu 20.04 及以后；`ldd --version` 看版本）：

  ```bash
  tar -xzf frey-*-linux-x86_64.tar.gz
  install -m 755 frey ~/.local/bin/frey        # 或 sudo install -m 755 frey /usr/local/bin/frey
  frey --version
  ```

- **macOS**：

  ```bash
  tar -xzf frey-*-macos-aarch64.tar.gz          # Intel 机器换 macos-x86_64
  xattr -d com.apple.quarantine frey            # 浏览器下载的才有隔离标记；还没有 Apple 公证
  install -m 755 frey ~/.local/bin/frey
  frey --version
  ```

### 从源码

源码仓不公开；`frey-core` 开源后这里会补上 `cargo install` 的方式。

## 快速开始

1. 按上面 [安装](#安装) 一句命令装好（或下载解压，见「手动装」）。
2. 到你的项目目录里运行 `frey`（Windows 也可以直接双击 `frey.exe`，它会先问在哪个项目目录里工作）：

   ```bash
   cd your-project
   frey
   ```

3. 第一次运行会弹出设置面板：**选服务商**（DeepSeek、OpenRouter、Ollama 等，打字可搜）→ **贴 key**（本机 Ollama 不用）→ Frey 试连一次 → **选模型** → 开始对话。

   key 存在 `~/.frey/auth.toml`（只有你能读），服务商和模型存在 `~/.frey/config.toml`，都由 Frey 自己写，不用手写。以后换模型用 `/model`（Ctrl+S 存为默认），改 key、权限模式等用 `/settings`。

不想先配 key、只想看看界面：`frey --tui-demo`（假回复，不联网）。环境变量、手写配置、脚本里怎么给 key，见 [进阶：配置文件与环境变量](#进阶配置文件与环境变量)。

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
| `/model [过滤词]` | 换模型：列出有 key 的服务商的模型，Enter 本会话用，Ctrl+S 存为默认 |
| `/settings` | 服务商与 key（加、换、删）、新会话的权限模式、启动时检查更新、插话键、动画；Windows 上还能把 Frey 加进当前用户的 PATH |
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
| `--provider <NAME>` | 本次用这家预设（`deepseek`、`openrouter`、`ollama` …），不改配置 |
| `--model <MODEL>` | 覆盖配置里的模型 |
| `--api-key <KEY>` | 本次用这个 key（优先于存着的和环境变量里的） |
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

### 连接器（MCP 服务器）：`frey connectors`

把一个 MCP 服务器接进来，它的工具就和内置工具一起给模型用（名字是 `mcp__<连接器>__<工具>`），审批照你的权限模式走：

```bash
frey connectors add files -- npx -y @modelcontextprotocol/server-filesystem ~/docs   # 本地服务器（stdio）
frey connectors add deepwiki --url https://mcp.deepwiki.com/mcp                      # 远程服务器（Streamable HTTP）
frey connectors list --check     # 都起一遍，看各自提供几个工具、有没有起不来的
frey connectors test files       # 服务器改了工具说明？逐项列出变了什么，再问你一次
frey connectors remove files
```

- 加的时候会把服务器的每个工具列给你看、问一次；**只有你批过、而且之后没变的工具才会交给模型**（批准记在 `~/.frey/connectors-approved.json`）。
- 工具说自己只读的直接跑；只追加、不出本机的在 `workspace-write` 下跑；其余（可能删东西、要连别的服务）要问你。想放开某个连接器：`permissions.allow_rules = ["mcp__deepwiki__*"]`。
- 配置在 `~/.frey/connectors.toml`；**密钥别写进去**，写 `headers = { Authorization = "Bearer ${MY_TOKEN}" }`，启动时从环境变量读。项目里的 `.frey/connectors.toml` 只能关掉连接器或缩小它的工具列表，不能加新的。

### 进阶：配置文件与环境变量

配置一般不用手写：首次运行的面板、`/model`、`/settings` 和下面的 `frey config` 都由程序写文件，**你手写的内容和注释会保留**。

```bash
frey config list                              # 看配置（key 只显示掩码）
frey config set provider.model deepseek-reasoner
frey config set-key deepseek                  # 隐藏输入 key；脚本里：echo "$KEY" | frey config set-key deepseek
frey config remove-key deepseek
frey config path                              # 两个文件在哪
```

key 按这个顺序取：`--api-key` ＞ `~/.frey/auth.toml` ＞ 环境变量。CI 和脚本里照旧可以只设环境变量：

```bash
export DEEPSEEK_API_KEY=sk-...                # PowerShell: $env:DEEPSEEK_API_KEY = "sk-..."
frey prompt --provider deepseek "总结一下 src/ 的结构"
```

没有可用的 key 时 `frey prompt` 不发请求，提示一行后以退出码 2 退出。

想手写也可以，`~/.frey/config.toml`（Windows：`%USERPROFILE%\.frey\config.toml`）：

```toml
[provider]
vendor = "openrouter"                         # 预设会填好协议、地址、key 变量名
model = "cohere/north-mini-code:free"
```

| 文件 | 作用 |
|---|---|
| `~/.frey/config.toml` | 用户配置：服务商与模型、权限、工具、压缩、更新 |
| `~/.frey/auth.toml` | 各服务商的 API key（Frey 写；Unix 上只有你能读；Frey 的工具不读它） |
| `~/.frey/profiles/<名>.toml` | 一组可切换的设置 |
| `<项目>/.frey/config.toml` | 项目配置，只能收紧 |
| `AGENTS.md` 等指令文件 | 自动发现并放进 system prompt |
| `~/.frey/sessions/<id>.jsonl` | 会话，只追加，只给本人读 |

| 环境变量 | 作用 |
|---|---|
| 配置里 `provider.api_key_env` 指的那个 | API key，没存 key 时用（预设各有默认名，如 `DEEPSEEK_API_KEY`） |
| `NO_COLOR` | 不着色 |
| `FREY_THEME=light` | 浅色终端配色 |
| `FREY_TUI_BASIC=0\|1` | 强制关 / 开基本模式 |
| `FREY_PROGRAM_STATUS=0` | 不发 OSC 7501 程序状态（标签页上的「工作中 / 等审批 / 完成」） |

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
