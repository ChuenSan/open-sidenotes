import Foundation

struct SlashCommand: Identifiable, Equatable {
    let id = UUID()
    let trigger: String
    let title: String
    let description: String
    let template: String
    let icon: String
    let needsLanguageSelector: Bool

    static let cursorMarker = "<|cursor|>"

    static let allCommands: [SlashCommand] = [
        SlashCommand(
            trigger: "h1",
            title: "一级标题",
            description: "大号章节标题",
            template: "# ",
            icon: "textformat.size.larger",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "h2",
            title: "二级标题",
            description: "中号章节标题",
            template: "## ",
            icon: "textformat.size",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "quote",
            title: "引用",
            description: "插入引用块",
            template: "> \(cursorMarker)",
            icon: "text.quote",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "h3",
            title: "三级标题",
            description: "小号章节标题",
            template: "### ",
            icon: "textformat.size.smaller",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "todo",
            title: "任务列表",
            description: "创建任务项",
            template: "- [ ] ",
            icon: "checkmark.square",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "ul",
            title: "无序列表",
            description: "无序列表项",
            template: "- ",
            icon: "list.bullet",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "ol",
            title: "有序列表",
            description: "有序列表项",
            template: "1. ",
            icon: "list.number",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "code",
            title: "代码块",
            description: "插入代码片段",
            template: "```\n\n```",
            icon: "chevron.left.forwardslash.chevron.right",
            needsLanguageSelector: true
        ),
        SlashCommand(
            trigger: "table",
            title: "表格",
            description: "插入 Markdown 表格",
            template: """
            | 列 1 | 列 2 | 列 3 |
            | --- | --- | --- |
            | \(cursorMarker) |  |  |
            """,
            icon: "tablecells",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "date",
            title: "日期",
            description: "插入当前日期",
            template: "",
            icon: "calendar",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "today",
            title: "今日",
            description: "插入今日章节",
            template: "",
            icon: "sun.max",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "meeting",
            title: "会议记录",
            description: "模板：会议记录",
            template: """
            # 会议记录
            - 日期：{{date}}
            - 参会人：
            - 议程：

            ## 笔记
            - \(cursorMarker)

            ## 行动项
            - [ ]
            """,
            icon: "person.3",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "daily",
            title: "日报",
            description: "模板：每日报告",
            template: """
            # 日报
            - 日期：{{date}}

            ## 已完成
            - \(cursorMarker)

            ## 进行中
            -

            ## 下一步
            -

            ## 阻塞问题
            -
            """,
            icon: "sunrise",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "issue",
            title: "问题记录",
            description: "模板：问题追踪笔记",
            template: """
            # 问题记录
            - 日期：{{date}}
            - 严重程度：
            - 状态：待处理

            ## 摘要
            \(cursorMarker)

            ## 复现步骤
            1.
            2.
            3.

            ## 预期结果

            ## 实际结果

            ## 修复计划
            - [ ]
            """,
            icon: "exclamationmark.triangle",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "bold",
            title: "粗体",
            description: "将文字加粗",
            template: "**text**",
            icon: "bold",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "italic",
            title: "斜体",
            description: "将文字倾斜",
            template: "*text*",
            icon: "italic",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "link",
            title: "链接",
            description: "插入超链接",
            template: "[text](url)",
            icon: "link",
            needsLanguageSelector: false
        )
    ]

    static func filter(by query: String) -> [SlashCommand] {
        if query.isEmpty || query == "/" {
            return allCommands
        }

        let searchTerm = query.hasPrefix("/") ? String(query.dropFirst()) : query
        return allCommands.filter { command in
            command.trigger.lowercased().hasPrefix(searchTerm.lowercased()) ||
            command.title.lowercased().contains(searchTerm.lowercased()) ||
            command.description.lowercased().contains(searchTerm.lowercased())
        }
    }

    func resolvedTemplate(referenceDate: Date = Date()) -> String {
        switch trigger {
        case "date":
            return Self.dateFormatter.string(from: referenceDate)
        case "today":
            return """
            ## Today \(Self.dateFormatter.string(from: referenceDate))
            - \(Self.cursorMarker)
            """
        case "daily":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        case "meeting":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        case "issue":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        default:
            return template
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
