# tmux 输入法管理

## US-0010: tmux pane 输入法状态管理

作为 tmux 用户，我希望在切换 pane 时自动恢复该 pane 的输入法状态，以便无缝继续工作。

### 验收标准

**输入法保存与恢复**

#### AC-0010-0010: 切换输入法时保存状态

- Given: 用户在 pane A 中工作
- When: 用户切换输入法为中文
- Then: pane A 的输入法状态保存为中文

#### AC-0010-0020: 切换 pane 时恢复已保存的输入法

- Given: pane A 输入法状态为中文，pane B 输入法状态为英文，当前在 pane B
- When: 用户切换到 pane A
- Then: 系统输入法切换为中文

#### AC-0010-0030: 切换到新建 pane 时使用默认输入法

- Given: pane A 是新建 pane，无输入法状态
- When: 用户切换到 pane A
- Then: 系统输入法切换为默认英文

**Prefix 模式**

#### AC-0010-0040: 进入 prefix 模式时切换为英文

- Given: 用户在 pane 中，输入法为中文
- When: 用户按下 C-a
- Then: 系统输入法切换为英文

#### AC-0010-0050: 进入 prefix 模式时保持英文（已为英文）

- Given: 用户在 pane 中，输入法为英文
- When: 用户按下 C-a
- Then: 系统输入法保持英文

#### AC-0010-0060: prefix 后执行命令再切回时恢复正确状态

- Given: 用户在 pane A，输入法为中文
- When: 用户按 C-a + c 新建窗口后切回 pane A
- Then: 系统输入法恢复为中文

#### AC-0010-0070: prefix 后进入 copy-mode 再退出时恢复正确状态

- Given: 用户在 pane 中，输入法为中文
- When: 用户按 C-a + Escape 进入 copy-mode，再退出 copy-mode
- Then: 系统输入法恢复为中文

#### AC-0010-0080: prefix 取消后恢复输入法（暂未实现）

- Given: 用户在 pane 中，输入法为中文
- When: 用户按 C-a 后取消（超时或按无效键）
- Then:
  - 预期行为: 系统输入法恢复为中文
  - 当前行为: 输入法保持英文，需手动切换
  - 原因: tmux 无 prefix 取消的 hook，计划下一版本实现

**Copy-mode**

#### AC-0010-0090: 进入 copy-mode 时切换为英文

- Given: 用户在 pane 中，输入法为中文
- When: 用户通过鼠标滚轮进入 copy-mode
- Then: 系统输入法切换为英文

#### AC-0010-0100: 退出 copy-mode 时恢复输入法

- Given: 用户在 pane 中，输入法为中文，通过鼠标滚轮进入 copy-mode
- When: 用户退出 copy-mode
- Then: 系统输入法恢复为中文

#### AC-0010-0110: copy-mode 中切换 pane 后切回时恢复正确状态

- Given: 用户在 pane A，输入法为中文，进入 copy-mode
- When: 用户切换到 pane B 再切回 pane A
- Then: 系统输入法恢复为中文

**边界场景**

#### AC-0010-0120: 非终端应用不触发同步

- Given: 用户在浏览器中工作
- When: 用户切换输入法
- Then: 不触发 tmux 输入法同步

#### AC-0010-0130: 从非终端应用切回终端时同步

- Given: 用户在浏览器中，输入法为中文
- When: 用户切回终端
- Then: 当前 pane 的输入法状态更新为中文

#### AC-0010-0140: prefix 期间切走再切回时保持已保存状态

- Given: 用户在 pane 中，输入法为中文，按 C-a 后切到浏览器
- When: 用户在浏览器中切换输入法，再切回终端
- Then: pane 的输入法状态保持为中文（不被浏览器中的输入法覆盖）

#### AC-0010-0150: copy-mode 期间切走再切回时保持已保存状态

- Given: 用户在 pane 中，输入法为中文，进入 copy-mode 后切到浏览器
- When: 用户在浏览器中切换输入法，再切回终端
- Then: pane 的输入法状态保持为中文（不被浏览器中的输入法覆盖）

**多 Session 场景**

#### AC-0010-0160: 多 session 时保存到正确的 pane

- Given: session A 和 session B 在不同终端窗口打开
- When: 用户在 session A 窗口中切换输入法
- Then: 输入法状态保存到 session A 的 active pane，不影响 session B

### 补充说明

- 默认输入法: `com.apple.keylayout.ABC`
- 输入法状态随 pane 生命周期自动管理，pane 关闭时自动清理

## US-0020: tmux pane 边框颜色同步

作为 tmux 用户，我希望 pane 边框颜色反映当前输入法状态，以便快速识别输入法。

### 验收标准

**颜色映射**

#### AC-0020-0010: Rime 中文输入法显示红色边框

- Given: 用户在终端中
- When: 输入法切换为 Rime 中文
- Then: active pane 边框颜色变为红色 (`#E53935`)

#### AC-0020-0020: Google 日文输入法显示蓝色边框

- Given: 用户在终端中
- When: 输入法切换为 Google 日文
- Then: active pane 边框颜色变为蓝色 (`#2C78BF`)

#### AC-0020-0030: 其他输入法显示默认边框

- Given: 用户在终端中
- When: 输入法切换为英文或其他未映射的输入法
- Then: active pane 边框颜色变为默认色 (`brightmagenta`)

**颜色更新**

#### AC-0020-0040: 手动切换输入法时边框颜色立即更新

- Given: 用户在终端中，边框为默认色
- When: 用户手动切换输入法为中文
- Then: 边框颜色立即变为红色

#### AC-0020-0050: 切换 pane 时边框颜色立即更新

- Given: pane A 输入法状态为中文，pane B 输入法状态为英文，当前在 pane B
- When: 用户切换到 pane A
- Then: 边框颜色立即变为红色

#### AC-0020-0060: prefix/copy-mode 期间边框颜色保持不变

- Given: 用户在 pane 中，输入法为中文，边框为红色
- When: 用户进入 prefix 模式或 copy-mode
- Then: 边框颜色保持红色

**多 Session 场景**

#### AC-0020-0070: 不同 session 独立边框颜色

- Given: session A 和 session B 在不同终端窗口打开
- When: 用户在 session A 切换输入法为中文
- Then: session A 边框变为红色，session B 边框保持原有颜色

#### AC-0020-0080: 切换终端窗口时边框颜色正确

- Given: session A 输入法为中文（红色），session B 输入法为英文（默认色）
- When: 用户从 session A 窗口切换到 session B 窗口
- Then: session B 窗口边框显示默认色

### 补充说明

- 边框颜色随输入法状态存储在 pane 级别
- 切换 pane 时 tmux 自动读取目标 pane 的颜色，实现即时更新
- 设计决策: prefix/copy-mode 时边框颜色保持不变，反映已保存的输入法，便于用户预知将恢复的输入法
