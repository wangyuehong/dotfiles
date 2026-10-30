# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 常用命令

初始化（首次使用）：

```bash
make setup          # 创建目录、安装 Homebrew 包、符号链接 dotfiles 和脚本
```

更新依赖：

```bash
make                # 全量更新：链接 dotfiles 和脚本、oh-my-zsh、插件、Homebrew、tmux 插件、Go 工具
make brew-up        # 更新 Homebrew formulae 和 cask，自动确认
make go-tools       # 仅更新 Go 工具
make py-tools       # 仅更新 Python 工具
```

运行测试：

```bash
make test                      # 运行全部 BATS 测试
bats scripts/tmux-im.bats     # 运行单个测试文件
```

## 架构

### 文件清单

Dotfiles（`make ln-dotfiles` -> `~/.{file}`，清单省略 `.` 前缀）：

- Shell：`aliases`, `bash_profile`, `zprofile`, `zshrc`
- Git：`gitconfig`, `gitignore`
- 编辑器：`vimrc`, `editorconfig`, `ctags`
- 终端与 CLI 工具：`tmux.conf`, `tigrc`, `psqlrc`, `myclirc`, `ripgreprc`

配置文件（`make ln-dotfiles` -> `~/.config/`）：

- `direnv.toml` -> `~/.config/direnv/direnv.toml`
- `direnvrc` -> `~/.config/direnv/direnvrc`
- `ghostty.toml` -> `~/.config/ghostty/config`
- `mise.toml` -> `~/.config/mise/config.toml`
- `rex.lua` -> `~/.config/rex/init.lua`

脚本（`make ln-scripts` -> `~/bin/`）：

- `tmux-im.sh` - 输入法边框同步（三件套完备）
- `tmux-fzf.sh` - fzf 文件选择器（三件套完备）
- `tmux-open.sh` - 按住 Option 点击打开路径或 URL（三件套完备）
- `tmux-window-name.sh` - 窗口名称生成（三件套完备）
- `worktree.sh` - git worktree 初始化（无 spec / 测试）

### 外部依赖

oh-my-zsh 生态（通过 `make upclone-all` 克隆）：

- `~/.oh-my-zsh` - 基础框架
- `~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`
- `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions`
- `~/.oh-my-zsh/custom/themes/spaceship-prompt`

tmux 插件（由 tpm 管理，位于 `~/.tmux/plugins/tpm`）：

- tmux-easymotion、tmux-fuzzback

### 代码风格

`.editorconfig` 定义格式规则：

- 默认 2 空格缩进，Python 使用 4 空格
- Go、Makefile，以及 `scripts/` 下的 shell 脚本与 BATS 测试使用 tab

### tmux 与脚本集成

`.tmux.conf` 通过 hook 和按键绑定调用 `scripts/` 下的脚本：

- `automatic-rename-format`: 调用 `tmux-window-name.sh #{pane_pid} #{window_panes}`
- `C-a` binding: 运行 `tmux-im.sh prefix #{pane_id}` 后进入 prefix 模式
- `prefix + C-f`: 在 popup 中启动 `tmux-fzf.sh`
- `M-MouseDown1Pane` 等按住 Option 的按下: 把点击处的 pane、文字与链接记入 `@tmux-open-*` 选项，进入 `tmux-open` 按键表
- `tmux-open` 表中按住 Option 的松开: 把记下的选项传给 `tmux-open.sh`
- `pane-focus-in` hook: 运行 `tmux-im.sh focus-in #{pane_id}`
- `pane-mode-changed` hook: 运行 `tmux-im.sh mode-changed #{pane_id} #{pane_mode}`

`tmux-im.sh` 子命令：

- `focus-in`：切换 pane 时同步边框颜色到当前输入法
- `mode-changed`：进入 copy-mode 时切换到英文，退出时同步边框颜色
- `prefix`：进入 prefix 模式前切换到英文
- `popup`：`tmux-open.sh` 弹出 popup 前切换到英文
- `sync`：由 Hammerspoon 在系统输入法变更时调用

边框颜色反映输入法状态：红色 = 中文（Rime）、蓝色 = 日语（Google 日本語入力）。

依赖：`macism`（Homebrew tap `laishulu/homebrew`）

## Shell 脚本规范

- Shebang: `#!/usr/bin/env bash`
- 安全选项：shebang 后 `set -euo pipefail`
- 函数命名：`snake_case`
- 局部变量：必须使用 `local`
- 常量 / 环境变量：`UPPER_CASE`
- 子命令脚本结构：`usage()` + `main()` + `case` dispatch
- Sourcing guard（脚本末尾，允许测试 source）:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

参考实现：`scripts/tmux-im.sh`

## 脚本开发

脚本遵循 spec 驱动开发，每个脚本必须包含三件套（命名：kebab-case，三文件同名）：

- `scripts/{name}.sh` - 实现
- `scripts/{name}.md` - spec（用户故事 + 验收标准）
- `scripts/{name}.bats` - BATS 测试

现有缺口：`worktree.sh` 无 spec 和测试。

### BATS 测试模式

文件结构（参考 `scripts/tmux-im.bats`）：

```bash
#!/usr/bin/env bats
# {name}.bats: Tests for {name}.sh
#
# Run: bats scripts/{name}.bats

# === Constants ===
# 测试用常量

# === Helpers ===
# 辅助函数（可选）

# === Setup/Teardown ===
setup() {
    source "${BATS_TEST_DIRNAME}/{name}.sh"
    # Mock 外部依赖: 定义同名函数 + export -f
}
teardown() { ... }

# === Section Name ===
@test "AC-XXXX-XXXX: 描述" { ... }
```

Mock 机制：

- 环境变量控制 mock 行为（如 `MOCK_IM`）
- 在 `setup()` 中 override 函数：`macism() { echo "${MOCK_IM:-default}"; }; export -f macism`
- 被测脚本通过 sourcing guard 提供函数供测试直接调用

测试命名：

- 对应 spec 验收标准：`@test "AC-XXXX-XXXX: 描述"`
- 补充测试：`@test "函数名: 描述"`

### Makefile 变更清单

新增脚本时：

- `SCRIPTS` 变量: 添加脚本文件名
- `test` target: 添加新的 `.bats` 文件路径

新增 dotfile 时：

- `DOTFILES` 变量: 添加省略 `.` 前缀的文件名

新增配置文件（`~/.config/` 目标）时：

- `CONFIG_LINKS` 变量: 添加 `源:目标` 对
- `setup` target: 添加 `mkdir -p` 创建目标目录

新增 Homebrew 包时：

- `setup` target: 添加到 `brew install` 行

## 注意事项

- 始终编辑仓库中的源文件，禁止直接修改 `~/` 下的符号链接目标
- 部分文件链接时改名：`ghostty.toml` -> `config`、`mise.toml` -> `config.toml`、`rex.lua` -> `init.lua`
- `make`（`all`）每次都运行 `ln-dotfiles` 与 `ln-scripts`；链接目标处已是普通文件或目录时不覆盖，处理完其余链接后列出这些路径并报错停下。这时把要保留的改动并回仓库的源文件（本机特有的放进「本地覆盖」一节的 local 文件），用 `trash` 移走它再重跑
- `worktree.sh` 无 sourcing guard，不可被 source
- `tmux-im.bats` 会创建和销毁临时 tmux session，其余测试文件不依赖 tmux server

## 本地覆盖

用户特定设置放在 local 文件中（不纳入仓库）：

- `~/.gitconfig.local` - Git 用户信息
- `~/.zshrc.local` - Shell 自定义配置
- `~/.tmux.conf.local` - tmux 覆盖配置
- `~/.config/mise/config.local.toml` - mise 工具版本
