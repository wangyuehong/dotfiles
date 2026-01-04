# tmux 文件选择器

## US-0010: fzf 文件选择

作为 tmux 用户，我希望在 tmux 会话中快速选择文件或目录并将路径插入到当前命令行，以便提高文件路径输入效率。

### 验收标准

**基本选择**

#### AC-0010-0010: 选择文件

- Given: 用户在 tmux 会话中执行脚本
- When: 用户在 fzf 中选择一个文件
- Then: 选中的文件路径被发送到当前 pane 的命令行

#### AC-0010-0020: 选择目录

- Given: 用户在 fzf 界面中
- When: 按 Ctrl-D 切换到目录模式并选择一个目录
- Then: 选中的目录路径被发送到当前 pane 的命令行

#### AC-0010-0030: 多选

- Given: 用户在 fzf 界面中
- When: 使用 Tab 选择多个文件后确认
- Then: 所有选中的文件路径以空格分隔发送到命令行

#### AC-0010-0040: 取消选择

- Given: 用户在 fzf 界面中
- When: 按 Esc 或 Ctrl-C 取消选择
- Then: 不发送任何内容到命令行，脚本正常退出

**类型切换**

#### AC-0010-0050: 从文件切换到目录

- Given: 用户在 fzf 界面中，当前为文件模式
- When: 按 Ctrl-D
- Then: 切换到目录模式，提示符更新显示 Dirs

#### AC-0010-0060: 从目录切换到文件

- Given: 用户在 fzf 界面中，当前为目录模式
- When: 按 Ctrl-D
- Then: 切换到文件模式，提示符更新显示 Files

**预览**

#### AC-0010-0070: 文件内容预览

- Given: 用户在 fzf 界面中
- When: 光标移动到一个文件上
- Then: 预览窗口显示文件内容（带行号和语法高亮）

#### AC-0010-0080: 目录内容预览

- Given: 用户在 fzf 界面中
- When: 光标移动到一个目录上
- Then: 预览窗口显示目录的树形结构（自动检测，无需切换模式）

### 补充说明

- 从当前 pane 所在目录开始搜索（可通过 Ctrl-H 导航到父目录）
- 隐藏文件（.开头）包含在搜索结果中
- .git 目录被排除
- 目录预览最多显示 30 行
- 预览工具降级：bat/batcat 不可用时使用 cat（无行号和高亮），tree 不可用时使用 ls
- 输出末尾包含空格便于继续输入

## US-0020: 路径模式

作为 tmux 用户，我希望能在不同路径格式之间切换，以便根据场景选择最适合的路径表示方式。

### 验收标准

**默认模式**

#### AC-0020-0010: Git 仓库内默认 Git 相对路径

- Given: 当前目录在 git 仓库内
- When: 执行脚本
- Then: 提示符显示 Git 模式，选择文件后输出相对于 git 仓库根目录的路径

#### AC-0020-0020: Git 仓库外默认绝对路径

- Given: 当前目录不在 git 仓库内
- When: 执行脚本
- Then: 提示符显示 Abs 模式，选择文件后输出绝对路径

**模式切换**

#### AC-0020-0030: Git 仓库内切换到绝对路径

- Given: 当前目录在 git 仓库内，fzf 界面已打开
- When: 按 Ctrl-T
- Then: 提示符显示 Abs 模式

#### AC-0020-0040: Git 仓库内再次切换回 Git 相对路径

- Given: 当前目录在 git 仓库内，已切换到 Abs 模式
- When: 再次按 Ctrl-T
- Then: 提示符显示 Git 模式

#### AC-0020-0050: Git 仓库外切换到相对路径

- Given: 当前目录不在 git 仓库内，fzf 界面已打开
- When: 按 Ctrl-T
- Then: 提示符显示 Rel 模式

#### AC-0020-0060: Git 仓库外再次切换回绝对路径

- Given: 当前目录不在 git 仓库内，已切换到 Rel 模式
- When: 再次按 Ctrl-T
- Then: 提示符显示 Abs 模式

**路径输出**

#### AC-0020-0070: Git 模式输出相对路径

- Given: 在 Git 模式下，git 仓库根目录为 /home/user/project
- When: 选择 /home/user/project/src/main.go
- Then: 输出 src/main.go

#### AC-0020-0080: Abs 模式输出绝对路径

- Given: 在 Abs 模式下
- When: 选择 $HOME/project/main.go
- Then: 输出 ~/project/main.go

#### AC-0020-0090: Rel 模式输出相对路径

- Given: 在 Rel 模式下，当前目录为 /home/user/project
- When: 选择 /home/user/project/src/main.go
- Then: 输出 src/main.go

#### AC-0020-0100: Git 模式导航后选择外部文件使用绝对路径

- Given: 在 Git 模式下，通过 Ctrl-H 导航到 git 仓库外
- When: 选择一个不在 git 仓库内的文件
- Then: 输出绝对路径（~/...），而非相对路径

#### AC-0020-0110: Rel 模式导航后选择外部文件使用绝对路径

- Given: 在 Rel 模式下，通过 Ctrl-H 导航到 pane 目录外
- When: 选择一个不在原始 pane 目录内的文件
- Then: 输出绝对路径（~/...），而非相对路径

#### AC-0020-0120: 导航后选择内部文件仍使用相对路径

- Given: 在 Git/Rel 模式下，通过 Ctrl-H/Ctrl-L 导航后
- When: 选择一个在基准目录（Git 仓库或 pane 目录）内的文件
- Then: 仍输出相对路径

### 补充说明

- 当缺少 grealpath 时，git/rel 模式回退到绝对路径
- Abs 模式下 $HOME 前缀统一替换为 ~
- 导航后选择外部文件时，自动使用绝对路径（无论当前模式）

## US-0030: AI 工具集成

作为 AI 工具（claude/gemini/codex）用户，我希望选择的文件路径自动添加 @ 前缀，以便直接作为 AI 工具的文件引用使用。

### 验收标准

**AI 工具检测**

#### AC-0030-0010: 检测到 AI 工具时使用 @ 前缀

- Given: 当前 pane 正在运行 claude
- When: 选择一个文件
- Then: 输出格式为 @path/to/file（带 @ 前缀）

#### AC-0030-0020: 检测到 gemini 时使用 @ 前缀

- Given: 当前 pane 正在运行 gemini
- When: 选择一个文件
- Then: 输出格式为 @path/to/file

#### AC-0030-0030: 检测到 codex 时使用 @ 前缀

- Given: 当前 pane 正在运行 codex
- When: 选择一个文件
- Then: 输出格式为 @path/to/file

**输出格式**

#### AC-0030-0040: AI 工具环境下多文件输出

- Given: 当前 pane 正在运行 AI 工具
- When: 选择多个文件
- Then: 每个路径都带 @ 前缀，以空格分隔（如 @file1 @file2）

#### AC-0030-0050: AI 工具环境下特殊字符转义

- Given: 当前 pane 正在运行 AI 工具
- When: 选择包含特殊字符（空格、引号、$、反引号、反斜杠）的文件
- Then: 路径使用单引号包裹（如 @'path with space.txt'）

#### AC-0030-0060: AI 工具环境下单引号转义

- Given: 当前 pane 正在运行 AI 工具
- When: 选择包含单引号的文件 file'name.txt
- Then: 单引号正确转义（如 @'file'\''name.txt'）

#### AC-0030-0070: 非 AI 工具环境输出

- Given: 当前 pane 未运行 AI 工具
- When: 选择文件
- Then: 输出 shell 转义后的路径，不带 @ 前缀

#### AC-0030-0080: 非 AI 工具环境特殊字符转义

- Given: 当前 pane 未运行 AI 工具
- When: 选择包含空格的文件 path with space.txt
- Then: 路径使用 shell 转义（如 path\ with\ space.txt）

#### AC-0030-0090: 非 AI 工具环境 ~ 路径保持可展开

- Given: 当前 pane 未运行 AI 工具，在 Abs 模式下
- When: 选择 $HOME/project/main.go
- Then: 输出 ~/project/main.go（~ 不被转义为 \~，保持 shell 可展开）

## US-0040: 父目录导航

作为 tmux 用户，我希望在 fzf 界面中能够导航到父目录，以便选择当前目录或 git 仓库之外的文件。

### 验收标准

#### AC-0040-0010: 导航到父目录

- Given: 用户在 fzf 界面中，当前搜索目录为 /home/user/project
- When: 按 Ctrl-H
- Then: 搜索目录切换到 /home/user，列表显示父目录下的文件和目录（混合显示）

#### AC-0040-0020: 连续导航

- Given: 用户已按 Ctrl-H 导航到父目录
- When: 再次按 Ctrl-H
- Then: 继续导航到更上层目录

#### AC-0040-0030: 根目录边界

- Given: 用户已导航到根目录 /
- When: 按 Ctrl-H
- Then: 保持在根目录，不发生变化

#### AC-0040-0040: 切换类型后保持目录

- Given: 用户已按 Ctrl-H 导航到父目录
- When: 按 Ctrl-D 切换文件/目录类型
- Then: 继续在当前导航目录下搜索，不重置到原始目录

#### AC-0040-0050: Header 显示当前搜索目录

- Given: 用户在 fzf 界面中
- When: 界面打开时
- Then: Header 第一行显示当前搜索目录路径（$HOME 缩写为 ~）

#### AC-0040-0060: 导航后 Header 更新

- Given: 用户在 fzf 界面中，Header 显示 ~/project
- When: 按 Ctrl-H 导航到父目录
- Then: Header 更新显示父目录路径

#### AC-0040-0070: 进入子目录

- Given: 用户在 fzf 界面中，光标在一个目录上
- When: 按 Ctrl-L
- Then: 搜索目录切换到选中的目录，列表显示该目录下的文件和目录（混合显示），Header 更新

#### AC-0040-0080: 非目录时 Ctrl-L 无效

- Given: 用户在 fzf 界面中，光标在一个文件上
- When: 按 Ctrl-L
- Then: 无变化

### 补充说明

- 默认从当前 pane 目录开始搜索
- Ctrl-H: 导航到父目录（混合显示文件和目录）
- Ctrl-L: 进入选中的子目录（混合显示文件和目录）
- 导航时始终混合显示文件和目录，便于继续导航或选择文件
- 导航不改变路径模式（Git/Abs/Rel）的行为
- 导航后选择的文件仍按当前路径模式格式化输出

## US-0050: 错误处理

作为用户，我希望在环境不满足要求时得到明确的错误提示。

### 验收标准

#### AC-0050-0010: 非 tmux 环境错误

- Given: 用户不在 tmux 会话中
- When: 执行脚本
- Then: 输出错误信息 "Error: This script must be run inside a tmux session." 并以非零状态退出

#### AC-0050-0020: 缺少 fd 命令错误

- Given: 系统未安装 fd 或 fdfind 命令
- When: 执行脚本
- Then: 输出错误信息 "Error: Required command 'fd' or 'fdfind' not found." 并以非零状态退出

### 补充说明

- 支持 macOS 和 Linux
- bat/batcat、tree、grealpath 为可选依赖，缺失时自动降级
