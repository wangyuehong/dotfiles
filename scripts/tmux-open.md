# tmux 点击打开路径与 URL

## US-0010: 按住 Option 点击打开

作为 tmux 用户，我希望按住 Option 点击 pane 中的路径或 URL 就能打开它。

路径在同一 session 的 Emacs pane 中打开并跳到行号，URL 交给系统默认程序打开（`http` 与 `https` 即默认浏览器）。

### 验收标准

**目标识别**

#### AC-0010-0010: 带 OSC 8 链接的文字

- Given: 鼠标下的文字带 OSC 8 链接
- When: 用户按住 Option 点击该文字
- Then: 按链接目标打开，不按可见文字打开

#### AC-0010-0020: 无链接的路径文字

- Given: 鼠标下的文字没有链接，是一段被空白、引号、括号、反引号或中日文标点包围的路径
- When: 用户按住 Option 点击该路径中的任一字符
- Then: 打开整段路径，句末的 `.`、`,`、`;`、`:`、`!`、`?` 与开头的 `@` 不算入路径

#### AC-0010-0030: 行中含全角字符

- Given: 路径之前有中日文等全角字符或 emoji
- When: 用户按住 Option 点击该路径
- Then: 打开的是鼠标下的那段路径，不因这些字符占两列而错位

#### AC-0010-0040: 鼠标下没有目标

- Given: 鼠标下是空白或分隔符
- When: 用户按住 Option 点击
- Then: 状态栏提示 `no path or URL under the mouse`，焦点与 Emacs 不变

**URL**

#### AC-0010-0050: 打开 URL

- Given: 目标以任意 `协议名://` 开头（如 `https://`、`vscode://`），且不是 `file://`
- When: 用户按住 Option 点击
- Then: URL 交给系统默认程序打开，Emacs 与焦点不变

**路径**

#### AC-0010-0060: 路径的解析基准

- Given: 目标是路径
- When: 用户按住 Option 点击
- Then: 按下表解析为绝对路径

| 目标形式 | 解析结果 |
|----------|----------|
| `file:///a/b%20c.go` | `/a/b c.go` |
| `/abs/a.go` | `/abs/a.go` |
| `~/a.go` | `$HOME/a.go` |
| `src/a.go`（可见文字，或不带协议的链接目标） | 被点击 pane 的当前目录下的 `src/a.go` |

#### AC-0010-0070: 行号与列号

- Given: 目标以下列任一形式结尾；链接目标不带行号时，看可见文字
  - `:行`、`:行:列`、`:起始行-结束行`、`:起始行-结束行:列`
  - `#L行`、`#L行C列`、`#L行-L结束行`
- When: 用户按住 Option 点击
- Then: Emacs 打开文件后光标位于该行（有列号时位于该列；行范围取起始行）

#### AC-0010-0080: 在 Emacs pane 中打开

- Given: 同一 session 中有运行 Emacs 的 pane，且 Emacs 已启动 server
- When: 用户按住 Option 点击一个存在的路径
- Then:
  - 文件在该 Emacs 已有的 frame 中打开，不新建 frame
  - 焦点切换到该 Emacs 所在的 window 与 pane

#### AC-0010-0090: 路径不存在

- Given: 解析后的路径不存在
- When: 用户按住 Option 点击
- Then: 状态栏提示 `not found: <路径>`，焦点与 Emacs 不变

#### AC-0010-0100: 没有 Emacs pane

- Given: 同一 session 中没有运行 Emacs 的 pane
- When: 用户按住 Option 点击一个存在的路径
- Then: 状态栏提示 `no Emacs pane in this session`，焦点不变

### 补充说明

- 状态栏提示停留 2 秒，期间按键与松开鼠标不会关闭它
- 没有链接、又被折成多行显示的路径，只能识别到鼠标所在那一行的部分
- 全角判定按 Unicode 东亚宽字符与 emoji 的主要区段，区段外的宽字符仍可能错位
