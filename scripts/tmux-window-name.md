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

### 补充说明

- 使用 tmux `automatic-rename-format` 配置调用此脚本：`#(tmux-window-name.sh #{pane_pid} #{window_panes})`
- 解释器检测支持：node、nodejs、python、python3、ruby、perl
- 可通过环境变量 `INTERPRETERS` 自定义解释器正则
- 可通过环境变量 `MULTI_PANE_INDICATOR` 自定义多 pane 标识（默认 `▪`）
- 窗口名称更新受 tmux `status-interval` 影响（tmux 默认 15 秒，本配置设为 1 秒）
