# CC 指令功能

## 概述
CC 指令功能移植自 aider 的 [watch files](https://aider.chat/docs/usage/watch.html) 功能，允许在代码注释中嵌入指令，让 Claude Code 自动识别并执行相应的代码修改任务。

## 触发器
- `CC` 或 `CC:` - 标记指令，等待触发
- `CC!` - 执行所有 CC 指令
- `CC?` - 回答问题

支持各语言注释格式，大小写不敏感。

## 使用方式

### 1. 上下文指令
在需要修改的位置直接添加注释说明更改需求：

```go
func Sqrt(n float64) (float64, error) {
    // Add error handling for NaN and negative values CC!
    return math.Sqrt(n), nil
}
```

### 2. 多注释协作
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

### 3. 注释块指令
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

### 4. 简化用法
可以使用小写且更简洁的表达：

```go
func Sum(a, b int) int { // cc!

// add factorial() cc!
```

## 处理规则
- 收集所有 CC 注释，CC! 或 CC? 触发执行
- 执行后删除所有 CC 标记
- 多个 CC 注释按顺序处理

## 使用命令
在 Claude Code 中使用以下命令来处理 CC 指令：

```
/cc [file_path]
```

如果不指定文件路径，默认行为如下：

与 IDE 同步时：
- 优先处理 IDE 当前选中的代码区域
- 如果没有选中区域，则处理 IDE 当前打开的文件

没有 IDE 同步时：
- 扫描当前目录下所有文件中的 CC 指令
