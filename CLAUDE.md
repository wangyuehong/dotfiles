# Claude Code 用户级规则

## 文件删除规则
- 永远不要使用 `rm` 命令删除文件和文件夹
- 必须使用 MacOS 废纸篓功能来移除文件
- 使用 `trash` 命令代替 `rm`
  ```bash
  trash filename   # 代替 rm filename
  trash -r dirname # 代替 rm -rf dirname
  ```

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
