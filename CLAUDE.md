# Claude Code 用户级规则

## 文件删除规则
- 永远不要使用 `rm` 命令删除文件和文件夹
- 必须使用 MacOS 废纸篓功能来移除文件
- 使用 `trash` 命令代替 `rm`
  ```bash
  trash filename   # 代替 rm filename
  trash -r dirname # 代替 rm -rf dirname
  ```

## 高效工具使用规则

### 核心原则
**一个命令行操作 > 多次工具调用**

### 必备命令

#### 模式搜索
```bash
rg -n "pattern" --glob '!vendor/*'  # 带行号搜索，排除vendor目录
```

#### 文件查找
```bash
fd filename          # 按名称查找
fd .ext directory    # 按扩展名在指定目录查找
```

#### 批量重构
```bash
# 查找并批量替换 - 一个命令替代几十次Edit调用！
rg -l "pattern" | xargs sed -i '' 's/old/new/g'
```

#### 项目结构
```bash
tree -L 2            # 快速查看项目结构
```

#### 数据处理
```bash
jq '.key' file.json  # 直接提取JSON数据
yq '.key' file.yaml  # 直接提取YAML数据
```

### 高效模式

#### 关键模式：查找 → 管道 → 批量转换
```bash
# 这一个命令可以替代几十次Edit工具调用！
rg -l "find_this" | xargs sed -i '' 's/replace_this/with_this/g'
```

### 工作流程检查清单
使用Read/Edit/Glob工具前，先考虑：
- 能用 `rg` 更快找到这个模式吗？
- 能用 `fd` 更快定位这些文件吗？
- 能用 `sed` 一次修复所有实例吗？
- 能用 `jq/yq` 直接提取数据吗？

### 实用组合
```bash
# 查找Go结构体定义
rg "type\s+\w+\s+struct" -t go

# 查找Go函数定义
rg "func\s+\w+" -t go

# 批量重命名
fd old_pattern | xargs -I {} mv {} {//}/new_name

# 统计Go代码行数
fd -e go | xargs wc -l
```

### 规则
- 优先使用CLI命令，避免多次工具调用
- 批量操作必须使用管道和xargs
- 搜索前用专业工具快速定位
- 记住：一个好的管道命令 > 几十次API调用

## CC 指令功能
当文件中的注释包含 `CC` 标记时，理解并执行相应指令。
移植自 aider 的 [watch files](https://aider.chat/docs/usage/watch.html) 功能。

### 触发器
- `CC` 或 `CC:` - 标记指令，等待触发
- `CC!` - 执行所有 CC 指令
- `CC?` - 回答问题

支持各语言注释格式，大小写不敏感。

### 用法

#### 上下文指令
在需要修改的位置直接添加注释说明更改需求：

```go
func Sqrt(n float64) (float64, error) {
    // Add error handling for NaN and negative values CC!
    return math.Sqrt(n), nil
}
```

#### 多注释协作
可以添加多个 `CC` 注释，最后用一个 `CC!` 触发：

```go
func Factorial(n int) int {
    // CC: refactor this code...
    result := 1
    for i := 1; i <= n; i++ {
        result *= i
    }
    // ...into a compute() function. CC!
    return result
}
```

#### 注释块指令
可以添加一个连续的注释块来提供详细指令。
只需确保其中一行以 `CC` 或 `CC!` 开头或结尾即可：

```go
// Make these changes: CC!
// - Add main() function
// - Accept -host and -port flags
// - Print welcome message with listening address
func run() {
    http.ListenAndServe(":8080", nil)
}
```

### 简化用法
可以使用小写且更简洁的表达：

```go
func Sum(a, b int) int { // cc!

// add factorial() cc!
```

### 规则
- 收集所有 CC 注释，CC! 或 CC? 触发执行
- 执行后删除所有 CC 标记
- 多个 CC 注释按顺序处理
