# tmux 窗口名称

## US-0010: 友好窗口名称

作为 tmux 用户，我希望窗口名称显示友好的程序名称，以便快速识别每个窗口中运行的内容。

### 验收标准

#### AC-0010-0010: Shell 显示 shell 名称

- Given: 一个 pane 运行 zsh/bash，没有子进程
- When: 调用 tmux-window-name.sh
- Then: 返回 shell 名称（如 "zsh"）

#### AC-0010-0020: 命令显示命令名称

- Given: 一个 pane 运行命令（如 vim）
- When: 调用 tmux-window-name.sh
- Then: 返回命令名称（如 "vim"）

#### AC-0010-0030: 解释器显示子进程名称

- Given: 一个 pane 运行 node 脚本（如 claude）
- When: 调用 tmux-window-name.sh
- Then: 返回脚本名称（如 "claude"），而非 "node"

#### AC-0010-0040: Emacs 显示友好名称

- Given: 一个 pane 运行 Emacs（任意变体如 Emacs-arm64-11）
- When: 调用 tmux-window-name.sh
- Then: 返回 "emacs"

#### AC-0010-0050: 空输入返回错误

- Given: 没有 pane_pid 参数
- When: 调用 tmux-window-name.sh
- Then: 以状态码 1 退出

#### AC-0010-0060: 无效 PID 返回 fallback

- Given: 一个不存在的 PID
- When: 调用 tmux-window-name.sh
- Then: 返回 "shell"（fallback）

#### AC-0010-0070: 多 pane 显示标识

- Given: 一个窗口有多个 pane（panes > 1）
- When: 调用 tmux-window-name.sh
- Then: 在名称前添加 `▪` 标识（如 "▪zsh"）

#### AC-0010-0075: 取前台进程，不取其他子进程

- Given: pane 的 shell 有多个子进程，如 zsh 插件在另一个终端上的 worker 与前台运行的 claude
- When: 调用 tmux-window-name.sh
- Then: 返回前台进程的名称（如 "claude"），即 shell 所在终端前台进程组的组长
- And: shell 自身是前台进程组组长时，取与 shell 同一进程组的第一个子进程，如 `new-window "cmd1; cmd2"` 中没有作业控制的 shell
- And: 没有这样的子进程时返回 shell 名称，如停在提示符、有 `sleep 300 &` 等后台作业或插件 worker 的交互 shell

#### AC-0010-0080: Claude Code 显示会话名

- Given: 解析出的程序名与第 3 个参数如下表
- When: 调用 tmux-window-name.sh
- Then: 返回如下表；多 pane 时照常加 `▪`
- Examples:

| 程序名 | 第 3 个参数 | 返回 |
|--------|-------------|------|
| `claude` | `fix-login` | `fix-login` |
| `claude` | 空或缺失 | `claude` |
| `zsh` | `fix-login`（Claude Code 退出后残留） | `zsh` |

### 补充说明

- 使用 tmux `automatic-rename-format` 配置调用此脚本：`#(tmux-window-name.sh #{pane_pid} #{n:#{P:#{?@agent-bar,,x}}} #{q:@agent-name})`
  - pane 数不计 my-agents-bar 的侧边栏
  - `@agent-name` 是 my-agents-bar 给 Claude Code pane 写的会话名；`#{q:}` 转义空格与 shell 特殊字符
  - 只在程序名为 `claude` 时采用：my-agents-bar 的侧边栏不在时，Claude Code 退出后选项可能残留
- 解释器检测支持：node、nodejs、python、python3、ruby、perl
- 可通过环境变量 `INTERPRETERS` 自定义解释器正则
- 可通过环境变量 `MULTI_PANE_INDICATOR` 自定义多 pane 标识（默认 `▪`）
- 窗口名称更新受 tmux `status-interval` 影响（tmux 默认 15 秒，本配置设为 1 秒）
