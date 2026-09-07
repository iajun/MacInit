# shell-init

macOS 开发环境一键初始化：Homebrew、GUI 应用、mise、Alacritty、zsh（zinit + Powerlevel10k）、tmux、Neovim（LazyVim）、pip、Git、AI Skills（Cursor / Claude / Codex）。

无参数进入交互向导；带参数走纯 CLI。破坏性操作前备份到 `~/.cache/shell-init/backups/`，支持 `--dry-run` 与幂等重跑。

配置与资产全部在本目录 `packages/` 下，不依赖仓库外的临时路径。

## 前提

- macOS（Apple Silicon / Intel）
- 网络（默认清华 Tuna Homebrew 镜像，可用 `--mirror=` 切换）
- 终端可执行 bash / zsh

## 30 秒快速开始

```bash
cd shell-init
chmod +x setup.sh
./setup.sh                  # 向导：按提示选 bootstrap 或 config
# 或全自动新机：
./setup.sh --preset=bootstrap --yes
```

预览（不改文件）：

```bash
./setup.sh --dry-run --preset=bootstrap
./setup.sh --dry-run --preset=apps-only --mirror=ustc
```

健康检查：

```bash
./setup.sh doctor
```

## 预设

| 预设 | 行为 |
|------|------|
| `bootstrap` | 新机：Xcode CLI + Homebrew + CLI Brewfile + GUI 应用 + mise + 全部配置 |
| `config` | 仅配置：mise / alacritty / zsh / pip / tmux / neovim / skills |
| `brew-only` | 仅 Homebrew + CLI Brewfile |
| `apps-only` | 仅 GUI（`Brewfile.apps`） |
| `fonts-only` | 仅额外字体（默认 meslo；见 `--fonts=`） |

向导推荐规则：无 `brew` → `bootstrap`；有 `brew` → `config`。

## CLI

```text
./setup.sh                              # 交互向导
./setup.sh --preset=bootstrap -y
./setup.sh --preset=config
./setup.sh --preset=apps-only
./setup.sh --steps=brew,apps,zsh,neovim,mise,skills
./setup.sh --dry-run --preset=bootstrap
./setup.sh --force --steps=neovim       # LazyVim 全量重装
./setup.sh --fail-fast
./setup.sh --mirror=tuna|ustc|ali|bfsu|official
./setup.sh --list-mirrors
./setup.sh --fonts=meslo,jetbrains
./setup.sh --skills-targets=cursor,claude
./setup.sh doctor
./setup.sh --help
```

| 选项 | 说明 |
|------|------|
| `--dry-run` | 只打印动作，不写文件系统 |
| `--yes` / `-y` | 跳过确认 |
| `--force` | 强制重装/覆盖（neovim 全量、已装 cask、覆盖已有 git 身份 / mise 本地文件等） |
| `--fail-fast` | 一步失败即停（默认继续并汇总） |
| `--mirror=` | Homebrew 镜像（见下） |
| `--fonts=` | 额外 Nerd Font（**默认不装**；Meslo 已在 Brewfile） |
| `--skills-targets=` | 覆盖自动识别：`cursor,claude` 或 `all`（默认按 targets.conf 探测） |

步骤 id：`brew` `apps` `mise` `alacritty` `zsh` `pip` `tmux` `neovim` `fonts` `git` `skills`  
兼容别名：`lazyvim` / `vim` → `neovim`；`skill` → `skills`。

环境变量：`GIT_USER_NAME` / `GIT_USER_EMAIL`（见 Git 身份）。

## Xcode Command Line Tools

bootstrap / brew 步骤会安装 CLT，**不会**自动化打开 Apple Developer 下载页并登录 Apple ID（脆弱、需交互浏览器，不适合生产引导）。

优先顺序：

1. 检测已安装（`xcode-select -p` + clang）
2. 用 `softwareupdate` 列出并安装匹配当前 macOS 的 “Command Line Tools for Xcode”（尽量非交互）
3. 回退 `xcode-select --install`，并提示在系统弹窗完成
4. 边缘情况可手动从 [Apple Developer Downloads](https://developer.apple.com/download/all/?q=command%20line%20tools) 下载（需 Apple ID）

`softwareupdate` 覆盖绝大多数新机场景；仅在企业网络限制或目录不可用时才需要手动 DMG。

## Homebrew 镜像

```bash
./setup.sh --mirror=tuna      # 默认
./setup.sh --mirror=ustc
./setup.sh --mirror=ali
./setup.sh --mirror=bfsu
./setup.sh --mirror=official
./setup.sh --list-mirrors
```

`apply_mirror_env` 会按镜像设置：

- `HOMEBREW_API_DOMAIN`
- `HOMEBREW_BOTTLE_DOMAIN`
- `HOMEBREW_BREW_GIT_REMOTE`
- `HOMEBREW_CORE_GIT_REMOTE`

选择会持久化到：

- `~/.config/shell-init/mirror`
- `~/.config/shell-init/brew-mirror.env`（zsh 经 `packages/zsh/brew_tsinghua.zsh` 加载）

### 镜像 URL 如何维护

URL 嵌在 `lib/mirrors.sh`（大学镜像帮助文档中的稳定环境变量）。权威来源：

| 镜像 | 文档 |
|------|------|
| tuna | https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/ |
| ustc | https://mirrors.ustc.edu.cn/help/brew.git.html |
| bfsu | https://mirrors.bfsu.edu.cn/help/homebrew/ |
| ali | https://developer.aliyun.com/mirror/homebrew |

刷新时对照文档，改 `lib/mirrors.sh`，并运行：

```bash
./scripts/update-mirrors.sh
```

## 软件管理（Brewfile）

两份标准 Brewfile，无自定义 catalog：

| 文件 | 步骤 | 内容 |
|------|------|------|
| `packages/Brewfile` | `brew` | CLI 工具 + Meslo 字体 |
| `packages/Brewfile.apps` | `apps` | GUI（Chrome、微信、MacPass 等） |

```bash
./setup.sh --preset=bootstrap          # 含 brew + apps
./setup.sh --preset=apps-only          # 只装 GUI
./setup.sh --steps=apps                # 同上，可与其它步骤组合
brew bundle install --file=packages/Brewfile.apps   # 也可直接 brew
```

增删软件：编辑对应 Brewfile（注释掉不需要的行），再跑对应步骤。

## mise

Brewfile 含 `mise`；`packages/mise/config.toml` 同步到 `~/.config/mise/config.toml`。  
zsh 在 `packages/zsh/config/path.zsh` 中 `mise activate`。

mise 步骤会安装全局运行时（见 `packages/mise/config.toml`）：

| 工具 | 版本 |
|------|------|
| node | `lts` |
| python | `3.12` |

改版本或加工具：编辑 `[tools]` 后 `./setup.sh --steps=mise --force`。项目级用根目录 `mise.toml`。

本地已有非链接的 `~/.config/mise/config.toml` 时默认保留（`--force` 才覆盖）；仍会执行 `mise install`。

## Git 身份

| 场景 | 行为 |
|------|------|
| 已有 `user.name` / `user.email` | 显示当前值；非交互默认保留；向导可选手动改 |
| 缺失 | 向导提示输入；CLI 用 `GIT_USER_NAME` / `GIT_USER_EMAIL` |
| `--yes` 且缺失且无 env | **警告并跳过**（不阻塞自动化） |
| 覆盖已有 | 需向导确认，或 `--force` + env |

不会在未确认时静默覆盖已有身份。

## AI Skills

统一维护 Agent Skills（各目录下的 `SKILL.md`），默认同步时**自动识别**本机已安装的 AI 工具，再软链接到对应技能目录。

| 路径 | 作用 |
|------|------|
| `packages/skills/<name>/SKILL.md` | 技能本体（唯一源） |
| `packages/skills/targets.conf` | 工具目录清单 + 探测路径（约 30+ 流行工具） |

默认识别：检查配置目录（如 `~/.cursor`）、App（如 `/Applications/Cursor.app`）、或 `cmd:claude` 等；命中才链接。共享路径（如 amp / kimi 同指向 `~/.config/agents/skills`）会去重。

```bash
# 添加技能后，自动链到已识别工具
mkdir -p packages/skills/my-skill
# 编辑 packages/skills/my-skill/SKILL.md
./setup.sh --steps=skills

# 强制指定 / 全部目标（跳过探测）
./setup.sh --steps=skills --skills-targets=cursor,claude
./setup.sh --steps=skills --skills-targets=all
```

`bootstrap` / `config` 预设已包含 `skills`。仅含 `SKILL.md` 的子目录会被链接；幂等，`--force` 可强制重链。增删工具条目：编辑 `targets.conf`。

## 备份与回滚

覆盖或删除配置前，会拷贝到：

```text
~/.cache/shell-init/backups/<timestamp>/
```

运行结束会打印备份路径。手动恢复示例：

```bash
cp -a ~/.cache/shell-init/backups/<ts>/.config/nvim ~/.config/nvim
```

**不做自动 rollback**；保留备份 + 本说明即可。

`~/.config/zsh/env.zsh`（本机密钥/身份）在 zsh 重置时会保留；首次从 `packages/zsh/env.example.zsh` 初始化。

## 目录说明

```text
shell-init/
  setup.sh              # 薄入口：向导 / CLI / 调度
  README.md             # 本产品文档
  lib/                  # common / sync / backup / ui / registry / mirrors
  modules/              # brew apps mise fonts alacritty zsh tmux neovim pip git skills
  packages/             # 纯配置资产
    Brewfile            # CLI
    Brewfile.apps       # GUI
    mise/config.toml
    skills/             # Agent Skills + targets.conf
    alacritty/ zsh/ tmux/ neovim/ pip/ git/
  scripts/
    doctor.sh           # 预检
    check.sh            # bash -n + shellcheck
    update-mirrors.sh   # 镜像 URL 维护提示
```

`packages/` 内配置可直接改；安装逻辑只改 `modules/` / `lib/`。

## 单独拆仓

本目录可整体拷贝为独立仓库使用。Monorepo 下 CI 在仓库根：

`.github/workflows/shell-init.yml`（`paths: shell-init/**`）

拆仓时把该 workflow 挪到新仓 `.github/workflows/ci.yml`，并把工作目录改为仓库根即可。

## 开发自检

```bash
./scripts/check.sh
./setup.sh --dry-run --preset=bootstrap
./setup.sh --dry-run --preset=apps-only --mirror=ustc
./setup.sh doctor
./scripts/update-mirrors.sh
```
