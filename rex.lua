-- Option 当 Alt、选中即复制是 Rex 的界面设置（系统偏好），由 make rex-defaults 写入

local terminal = "com.superlogical.terminal"

local function write(data)
  return function()
    rex.block.call(terminal, "write", { data = data })
    return true
  end
end

-- 默认 cmd+left/right 发裸 Ctrl-A/Ctrl-E，会被 tmux 的 C-a prefix 吞掉；
-- 与 ghostty.toml 一致，改发 khome/kend 转义序列
rex.bind("cmd+left", write("\27OH"))
rex.bind("cmd+right", write("\27OF"))
