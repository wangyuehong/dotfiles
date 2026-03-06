# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 常用命令

初始化（首次使用）：

```bash
make setup          # 创建目录、安装 Homebrew 包、符号链接 dotfiles 和脚本
```

更新依赖：

```bash
make                # 全量更新：oh-my-zsh、插件、Homebrew、tmux 插件、Go 工具
make brew-up        # 仅更新 Homebrew
make go-tools       # 仅更新 Go 工具
make py-tools       # 仅更新 Python 工具
```

运行测试：

```bash
make test                      # 运行全部 BATS 测试
bats scripts/tmux-im.bats     # 运行单个测试文件
```

## 架构

### 目录结构

- 根目录：配置 dotfiles（`.zshrc`、`.tmux.conf`、`.vimrc` 等）
- `scripts/`：自定义 shell 脚本，配套 spec 文档和 BATS 测试
- `Makefile`：安装自动化和依赖管理

### 符号链接策略

`make ln-dotfiles` 将仓库文件链接到 `~/.{file}`。配置目录使用 `~/.config/{app}/`：

- `direnv.toml` -> `~/.config/direnv/direnv.toml`
- `ghostty.toml` -> `~/.config/ghostty/config`
- `mise.toml` -> `~/.config/mise/config.toml`

`make ln-scripts` 将脚本链接到 `~/bin/`。

### 外部依赖

oh-my-zsh 生态（通过 `make upclone-all` 克隆）：

- `~/.oh-my-zsh` - 基础框架
- `~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`
- `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions`
- `~/.oh-my-zsh/custom/themes/spaceship-prompt`

tmux 插件（由 tpm 管理，位于 `~/.tmux/plugins/tpm`）：

- tmux-easymotion、tmux-fuzzback

### 代码风格

`.editorconfig` 定义格式规则：默认 2 空格缩进，Go 使用 tab，Python 使用 4 空格，Makefile 使用 tab。

### tmux 与脚本集成

`.tmux.conf` 通过 hook 和按键绑定调用 `scripts/` 下的脚本：

- `tmux-window-name.sh`：通过 `automatic-rename-format` 调用，根据运行进程动态生成窗口名
- `tmux-fzf.sh`：通过 `prefix + C-f` 在 popup 中启动文件选择器
- `tmux-im.sh`：输入法状态管理，支持多语言切换

`tmux-im.sh` 子命令：

- `focus-in`：切换 pane 时同步边框颜色到当前输入法
- `mode-changed`：进入 copy-mode 时切换到英文，退出时恢复
- `prefix`：进入 prefix 模式前保存输入法并切换到英文
- `sync`：由 Hammerspoon 在系统输入法变更时调用

边框颜色反映输入法状态：红色 = 中文（Rime）、蓝色 = 日语（Google 日本語入力）。

依赖：`macism`（Homebrew tap `laishulu/homebrew`）

## 脚本开发

脚本遵循 spec 驱动开发，验收标准写在 markdown 文件中：

- `scripts/tmux-im.md` - `tmux-im.sh` 的 spec
- `scripts/tmux-fzf.md` - `tmux-fzf.sh` 的 spec
- `scripts/tmux-window-name.md` - `tmux-window-name.sh` 的 spec

每个脚本配套 `.bats` 测试文件（BATS - Bash Automated Testing System）。

### 测试规范

- 测试命名对应 spec 中的验收标准：`@test "AC-XXXX-XXXX: 描述"`
- 脚本使用 sourcing guard（`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]`），允许测试文件直接 source 脚本访问内部函数
- Mock 机制：通过环境变量（如 `MOCK_IM`）和函数导出模拟外部依赖

## 本地覆盖

用户特定设置放在 local 文件中（不纳入仓库）：

- `~/.gitconfig.local` - Git 用户信息
- `~/.zshrc.local` - Shell 自定义配置
- `~/.tmux.conf.local` - tmux 覆盖配置
- `~/.config/mise/config.local.toml` - mise 工具版本
