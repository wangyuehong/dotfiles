# tmux 点击打开路径与 URL

## US-0010: 按住 Option 点击打开

作为 tmux 用户，我希望按住 Option 点击 pane 中的路径或 URL 就能打开它。

路径在点击所在的终端上弹出 popup，用 Emacs 打开并跳到行号，看完关闭 popup 即回到原处。

URL 交给系统默认程序打开（`http` 与 `https` 即默认浏览器）。

### 验收标准

#### AC-0010-0010: 带 OSC 8 链接的文字

- Given: 鼠标下的文字带 OSC 8 链接
- When: 用户按住 Option 点击该文字
- Then: 按链接目标打开，不按可见文字打开

#### AC-0010-0020: 无链接的路径文字

- Given: 鼠标下的文字没有链接，是一段被空白、引号、括号、反引号、中日文标点或框线字符包围的路径
  - 框线字符指 U+2500～U+259F，如面板边框 `│`
- When: 用户按住 Option 点击该路径中的任一字符
- Then: 打开整段路径，句末的 `.`、`,`、`;`、`:`、`!`、`?` 与开头的 `@` 不算入路径

#### AC-0010-0030: 行中含全角字符

- Given: 路径之前有中日文等全角字符或 emoji
- When: 用户按住 Option 点击该路径
- Then: 打开的是鼠标下的那段路径，不因这些字符占两列而错位

#### AC-0010-0040: 鼠标下没有目标

- Given: 鼠标下是空白或分隔符
- When: 用户按住 Option 点击
- Then: 状态栏提示 `no path or URL under the mouse`，不弹出 popup

#### AC-0010-0050: 打开 URL

- Given: 目标以任意 `协议名://` 开头（如 `https://`、`vscode://`），且不是 `file://`
- When: 用户按住 Option 点击
- Then: URL 交给系统默认程序打开，不弹出 popup

#### AC-0010-0060: 路径的解析基准

- Given: 目标是路径
- When: 用户按住 Option 点击
- Then: 按下表解析为绝对路径
  - 当前目录指被点击 pane 的当前目录，仓库根指当前目录所在 git 仓库的根目录
  - 当前目录不在 git 仓库中时没有仓库根，相对路径只按当前目录解析

| 目标形式 | 解析结果 |
|----------|----------|
| `file:///a/b%20c.go` | `/a/b c.go` |
| `/abs/a.go` | `/abs/a.go` |
| `~/a.go` | `$HOME/a.go` |
| `:/src/a.go` | 仓库根下的 `src/a.go` |
| `src/a.go`（可见文字，或不带协议的链接目标） | 当前目录下的 `src/a.go`，不存在时为仓库根下的 `src/a.go` |

#### AC-0010-0070: 行号与列号

- Given: 目标以下列任一形式结尾；链接目标不带行号时，看可见文字
  - `:行`、`:行:列`、`:起始行-结束行`、`:起始行-结束行:列`
  - `#L行`、`#L行C列`、`#L行-L结束行`
- When: 用户按住 Option 点击
- Then: Emacs 打开文件后光标位于该行（有列号时位于该列；行范围取起始行）

#### AC-0010-0080: 在 popup 中打开

- Given: Emacs 已启动 server
- When: 用户按住 Option 点击一个存在的路径
- Then:
  - 松开鼠标后，点击所在的终端上弹出居中的 popup，宽与高各为终端的 90%
  - popup 的标题是该路径，`$HOME` 显示为 `~`，`#` 等字符按字面显示
  - popup 中的 Emacs 显示该文件，目标是目录时显示 dired；光标不会先停在鼠标所在的位置
  - 被点击的 pane 收不到这次点击的按下、拖动与松开，不改变尺寸，当前 window 与 pane 不切换
  - popup 弹出前，输入法按 `tmux-im.md` 的 AC-0030-0010 切换为英文

#### AC-0010-0085: 关闭 popup

- Given: popup 中的 Emacs 正在显示点击的文件
- When: 用户在 Emacs 中用 `:q`、`ZZ` 或 `C-x #` 结束，或用 tmux 的 popup 菜单关闭 popup
- Then:
  - popup 关闭，回到点击前的 window 与 pane，状态栏没有提示
  - 本次打开时新建的 buffer 不留在 Emacs 中，打开前已有的文件 buffer 仍在

#### AC-0010-0090: 路径不存在

- Given: 解析后的路径不存在
- When: 用户按住 Option 点击
- Then: 状态栏提示 `not found: <路径>`，不弹出 popup
  - `<路径>` 是解析结果，相对路径为当前目录下的路径
  - 没有仓库根时 `:/` 形式的目标没有解析结果，`<路径>` 为原文，如 `:/src/a.go`

#### AC-0010-0100: 打开失败

- Given: Emacs 没有启动 server
- When: 用户按住 Option 点击一个存在的路径
- Then: popup 随即关闭，状态栏提示 `open failed (exit <退出码>)`

#### AC-0010-0110: 输入法切换失败时照常打开

- Given: 输入法无法切换，如没有安装 `macism`
- When: 用户按住 Option 点击一个存在的路径
- Then: popup 照常弹出，状态栏没有提示

#### AC-0010-0120: 关闭后提示输入法切换失败

- Given: 打开 popup 时输入法切换失败
- When: 用户关闭 popup
- Then: 状态栏提示 `input method switch failed (exit <退出码>)`

### 补充说明

- 状态栏提示停留 2 秒，期间的按键与鼠标操作都不生效
- 按下鼠标后移到别处再松开，打开的是按下处的目标，中途经过 pane 边框或状态栏也一样
- 以下情形不打开：在状态栏或 pane 边框上松开；拖进右侧的 pane 后松开，这时那个 pane 收到松开
- 快速连续点击时，每次打开的都是该次点击处的目标
- 先松开 Option 再松开鼠标时，不打开任何目标
- 不按 Option 按下鼠标、松开前才按住 Option 时，不打开任何目标，这次点击照常交给 pane
- 没有链接、又被折成多行显示的路径，只能识别到鼠标所在那一行的部分
- 没有链接的文字中，含空格的路径只能识别到空格前的部分；点到 `(hide)`、`+14` 这类文字时提示 `not found`
- 全角判定按 Unicode 东亚宽字符与 emoji 的主要区段，区段外的宽字符仍可能错位
- 链接目标以 `;` 结尾时，tmux 把它当作命令分隔符，提示 `open failed (exit 1)`
- 在 Emacs 所在的 window 中点击时，popup 盖在该 Emacs 上，显示同一个 Emacs 的另一个 frame
- popup 打开时，Emacs 中输入到一半的 minibuffer 会被中止
- 点击的文件已在 Emacs 中打开且有未保存的修改时，`:q` 询问是否保存，`ZZ` 直接保存
- 目标是目录时，Emacs 中事先打开的同一目录的 dired buffer 也会在关闭 popup 后被删除
- 用 tmux 的 popup 菜单把 popup 转成 pane 时，Emacs 留在新 pane 中，状态栏没有提示
