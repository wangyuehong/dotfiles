# Claude Code 用户级规则

## 文件删除规则
- 永远不要使用 `rm` 命令删除文件和文件夹
- 必须使用 MacOS 废纸篓功能来移除文件
- 使用 `trash` 命令代替 `rm`
  ```bash
  trash filename   # 代替 rm filename
  trash -r dirname # 代替 rm -rf dirname
  ```
