-- Option 当 Alt、选中即复制是 Rex 的界面设置（系统偏好），由 make rex-defaults 写入

local terminal = "com.superlogical.terminal"

local function write(data)
  return function()
    rex.block.call(terminal, "write", { data = data })
    return true
  end
end

-- 默认 cmd+left/right 发裸 Ctrl-A/Ctrl-E，会被 C-a prefix 吞掉；
-- 与 ghostty.toml 一致，改发 khome/kend 转义序列
rex.bind("cmd+left", write("\27OH"))
rex.bind("cmd+right", write("\27OF"))

-- prefix 机制对标 .tmux.conf：C-a 后的按键与 tmux 一致
local P = "ctrl+a>"
local function bind(key, action, args)
  rex.bind(P .. key, action, args)
end

bind("a", "pane.send_key", { key = "ctrl+a" })

-- window 即 Rex 的 tab；Rex 不显示 tab 序号，按侧边栏行数从 1 数
for i = 1, 9 do
  bind(tostring(i), "client.tab.goto", { index = i })
end
bind("c", "client.tab.new")
bind("ctrl+c", "client.tab.new")
-- pane.go_to（Go to Anything）在当前版本的应用里打不开，用侧边栏 tab 过滤代替 choose-tree
bind("w", "client.sidebar.filter.focus")
bind("n", "client.tab.next")
bind("p", "client.tab.previous")
bind(",", "client.tab.rename")
bind("shift+7", "client.tab.close")

-- pane
bind("-", "pane.split", { direction = "down" })
bind("shift+\\", "pane.split", { direction = "right" })
bind("\\", "pane.split", { direction = "right" })
bind("h", "pane.focus", { direction = "left" })
bind("j", "pane.focus", { direction = "down" })
bind("k", "pane.focus", { direction = "up" })
bind("l", "pane.focus", { direction = "right" })
bind("o", "pane.focus_next")
bind("ctrl+h", "pane.resize", { direction = "left" })
bind("ctrl+j", "pane.resize", { direction = "down" })
bind("ctrl+k", "pane.resize", { direction = "up" })
bind("ctrl+l", "pane.resize", { direction = "right" })
bind("z", "pane.zoom")
bind("x", "pane.close")
bind("shift+1", "pane.move_to_new_tab")
bind("]", "pane.paste")
bind("/", "client.find.open")

-- session
bind("s", "session.switch")
bind("shift+4", "session.rename")
bind("shift+9", "session.previous")
bind("shift+0", "session.next")

bind("r", "client.config.reload")
