import Foundation

enum Constants {
    static let appName = "OpenSidenotes"

    static let defaultWelcomeContent = """
# 欢迎使用 Open Sidenotes

你的想法，通过实时 Markdown 渲染被整洁地整理。

## Markdown 语法指南

### 文本格式
**粗体文字** — 用 `**双星号**` 包裹文字
*斜体文字* — 用 `*单星号*` 包裹文字
***粗体且斜体*** — 使用 `***三星号***`
`行内代码` — 用反引号包裹文字

### 标题
# 一级标题
## 二级标题
### 三级标题

### 列表
- 无序列表项 1
- 无序列表项 2
  - 嵌套项

1. 有序列表项 1
2. 有序列表项 2
3. 有序列表项 3

### 任务列表
- [ ] 未完成任务
- [x] 已完成任务（带删除线）
  - [ ] 嵌套子任务

### 链接与更多
[链接文字](https://example.com)
> 使用 `>` 引用块
`用反引号包裹的代码`

---

## 近期更新
- **任务列表** — 支持 `- [ ]` 待办与 `- [x]` 已完成语法
- **边缘触发激活** — 移动鼠标到屏幕左边缘即可切换面板
- **自动保存** — 更改后 1 秒自动保存
- **可自定义快捷键** — 默认：⌘⌃空格
- **会话保持** — 自动恢复上次打开的便签
- **设置面板** — 自定义 Dock 图标、自动隐藏、存储位置

---

**提示**：所有 Markdown 语法均可编辑。标题中的 `#` 和粗体文字中的 `**` 会被保留但以不同样式呈现。现在就开始书写吧 —— 你的便签会随着输入自动保存！
"""

    static let defaultNotesDirectoryName = "OpenSidenotes"

    static func defaultNotesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(defaultNotesDirectoryName, isDirectory: true)
    }
}
