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
- When: 选择一个目录
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

#### AC-0010-0050: 默认显示全部

- Given: 用户执行脚本
- When: fzf 界面打开
- Then: 列表显示文件和目录（混合），提示符显示 All

#### AC-0010-0060: 切换到仅文件

- Given: 用户在 fzf 界面中，当前为 All 模式
- When: 按 Ctrl-D
- Then: 切换到仅文件模式，提示符更新显示 Files

#### AC-0010-0070: 切换到仅目录

- Given: 用户在 fzf 界面中，当前为 Files 模式
- When: 按 Ctrl-D
- Then: 切换到仅目录模式，提示符更新显示 Dirs

#### AC-0010-0080: 切换回全部

- Given: 用户在 fzf 界面中，当前为 Dirs 模式
- When: 按 Ctrl-D
- Then: 切换回全部模式，提示符更新显示 All

**预览**

#### AC-0010-0090: 文件内容预览

- Given: 用户在 fzf 界面中
- When: 光标移动到一个文件上
- Then: 预览窗口显示文件内容（带行号和语法高亮）

#### AC-0010-0100: 目录内容预览

- Given: 用户在 fzf 界面中
- When: 光标移动到一个目录上
- Then: 预览窗口显示目录的树形结构（自动检测，无需切换模式）

### 补充说明

- Git 仓库内从 git 根目录开始搜索，仓库外从当前 pane 目录开始搜索
- 可通过 Ctrl-H/Ctrl-L 导航到其他目录
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
- Then: 提示符显示 Git 模式，候选列表显示相对于 git 根目录的路径，选择后输出相对路径

#### AC-0020-0020: Git 仓库外默认绝对路径

- Given: 当前目录不在 git 仓库内
- When: 执行脚本
- Then: 提示符显示 Abs 模式，选择文件后输出绝对路径

**模式切换**

#### AC-0020-0030: Git 仓库内切换到绝对路径

- Given: 当前目录在 git 仓库内，fzf 界面已打开
- When: 按 Ctrl-T
- Then: 提示符显示 Abs 模式，候选列表刷新显示绝对路径

#### AC-0020-0040: Git 仓库内再次切换回 Git 相对路径

- Given: 当前目录在 git 仓库内，已切换到 Abs 模式
- When: 再次按 Ctrl-T
- Then: 提示符显示 Git 模式，候选列表刷新显示相对路径
- Note: 如果已导航到 git 仓库外，按 Ctrl-T 无法切换到 Git 模式（无变化）

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
- When: 选择列表中显示的 src/main.go
- Then: 输出 src/main.go

#### AC-0020-0080: Abs 模式输出绝对路径

- Given: 在 Abs 模式下
- When: 选择 $HOME/project/main.go
- Then: 输出 ~/project/main.go

#### AC-0020-0090: Rel 模式输出相对路径

- Given: 在 Rel 模式下，当前目录为 /home/user/project
- When: 选择 /home/user/project/src/main.go
- Then: 输出 src/main.go

### 补充说明

- 当缺少 grealpath 时，rel 模式回退到绝对路径
- Abs 模式下 $HOME 前缀统一替换为 ~
- 导航时根据目标目录的 git 状态自动切换模式（见 US-0040）

## US-0030: 输出格式

作为用户，我希望选择的文件路径正确转义，以便在 shell 中安全使用。

### 验收标准

#### AC-0030-0010: 特殊字符转义

- Given: 用户选择包含空格的文件 path with space.txt
- When: 确认选择
- Then: 路径使用 shell 转义（如 path\ with\ space.txt）

#### AC-0030-0020: ~ 路径保持可展开

- Given: 用户在 Abs 模式下
- When: 选择 $HOME/project/main.go
- Then: 输出 ~/project/main.go（~ 不被转义为 \~，保持 shell 可展开）

### 补充说明

- 如需 @ 前缀（用于 AI 工具），用户可先输入 @ 再调用文件选择器

## US-0040: 父目录导航

作为 tmux 用户，我希望在 fzf 界面中能够导航到父目录，以便选择当前目录或 git 仓库之外的文件。

### 验收标准

#### AC-0040-0010: 导航到父目录

- Given: 用户在 fzf 界面中，当前搜索目录为 /home/user/project
- When: 按 Ctrl-H
- Then: 搜索目录切换到 /home/user，列表显示父目录下的文件和目录（混合显示），查询框清空

#### AC-0040-0020: 连续导航

- Given: 用户已按 Ctrl-H 导航到父目录
- When: 再次按 Ctrl-H
- Then: 继续导航到更上层目录

#### AC-0040-0030: 根目录边界

- Given: 用户已导航到根目录 /
- When: 按 Ctrl-H
- Then: 保持在根目录，不发生变化

#### AC-0040-0040: 切换类型后保持目录（Abs/Rel 模式）

- Given: 用户在 Abs/Rel 模式下，已按 Ctrl-H 导航到其他目录
- When: 按 Ctrl-D 切换类型（All/Files/Dirs）
- Then: 继续在当前导航目录下搜索，不重置到原始目录
- Note: Git 模式下切换类型始终搜索整个 git 仓库

#### AC-0040-0050: Header 显示当前目录

- Given: 用户在 fzf 界面中
- When: 界面打开时
- Then: Header 第一行显示当前 pane 目录路径（$HOME 缩写为 ~）
- Note: Git 模式下虽然搜索整个 git 仓库，Header 仍显示 pane 目录

#### AC-0040-0060: 导航后 Header 更新

- Given: 用户在 fzf 界面中，Header 显示 ~/project
- When: 按 Ctrl-H 导航到父目录
- Then: Header 更新显示父目录路径

#### AC-0040-0070: 进入子目录

- Given: 用户在 fzf 界面中，光标在一个目录上
- When: 按 Ctrl-L
- Then: 搜索目录切换到选中的目录，列表显示该目录下的文件和目录（混合显示），Header 更新，查询框清空

#### AC-0040-0080: 非目录时 Ctrl-L 无效

- Given: 用户在 fzf 界面中，光标在一个文件上
- When: 按 Ctrl-L
- Then: 无变化

**导航时自动切换模式**

#### AC-0040-0090: 导航到 git 仓库外自动切换到 Abs 模式

- Given: 用户在 Git 模式下，当前在 git 仓库内
- When: 按 Ctrl-H 导航到 git 仓库外的目录
- Then: 自动切换到 Abs 模式，候选列表显示绝对路径，提示符更新

#### AC-0040-0100: 进入 git 仓库自动切换到 Git 模式

- Given: 用户在 Abs 模式下，当前在 git 仓库外
- When: 按 Ctrl-L 进入一个 git 仓库内的目录
- Then: 自动切换到 Git 模式，候选列表显示相对路径，提示符更新

**导航后操作**

#### AC-0040-0110: 导航后切换类型使用当前 git root

- Given: 用户从非 git 目录导航进入 git 仓库，已自动切换到 Git 模式
- When: 按 Ctrl-D 切换类型（All/Files/Dirs）
- Then: 列表显示当前 git 仓库的相对路径，而非启动时的 git root

#### AC-0040-0120: 导航后切换模式使用当前 git root

- Given: 用户从一个 git 仓库导航到另一个 git 仓库
- When: 按 Ctrl-T 切换到 Git 模式
- Then: 列表显示当前 git 仓库的相对路径，而非启动时的 git root

### 补充说明

- Ctrl-H: 导航到父目录（混合显示文件和目录）
- Ctrl-L: 进入选中的子目录（混合显示文件和目录）
- 导航时始终混合显示文件和目录，便于继续导航或选择文件
- 导航时根据目标目录的 git 状态自动切换模式（Git/Abs）
- 导航后选择的文件按自动切换后的模式格式化输出

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
