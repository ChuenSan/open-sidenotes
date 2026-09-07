import Testing
import SwiftUI
import AppKit
@testable import open_sidenotes

struct open_sidenotesTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

class CodeBlockEditorTests {

    @Test func coordinatorCopiesCodeToClipboard() throws {
        let testCode = "let x = 42"
        let binding = Binding<String>(
            get: { testCode },
            set: { _ in }
        )

        let editor = CodeBlockEditor(
            code: binding,
            language: .swift,
            onCodeChange: { _ in }
        )

        let coordinator = editor.makeCoordinator()

        NSPasteboard.general.clearContents()
        coordinator.copyCode()

        let clipboardContent = NSPasteboard.general.string(forType: .string)
        #expect(clipboardContent == testCode, "Clipboard should contain the code after copyCode() is called")
    }

    @Test func coordinatorChangesCopyButtonIcon() throws {
        let testCode = "func test() {}"
        let binding = Binding<String>(
            get: { testCode },
            set: { _ in }
        )

        let editor = CodeBlockEditor(
            code: binding,
            language: .swift,
            onCodeChange: { _ in }
        )

        let coordinator = editor.makeCoordinator()

        let copyButton = NSButton()
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        coordinator.copyButton = copyButton

        coordinator.showCopyFeedback()

        #expect(copyButton.image?.accessibilityDescription == "Copied", "Icon should change to checkmark after showCopyFeedback()")
    }
}

struct QuickOpenSearchServiceTests {
    @Test func searchMatchesBodyContent() throws {
        let notes = [
            Note(title: "Untitled", content: "alpha beta keyword here"),
            Note(title: "Other", content: "nothing")
        ]

        let result = QuickOpenSearchService.rankedNotes(
            from: notes,
            query: "keyword",
            recentNoteIDs: []
        )

        #expect(result.first?.title == "Untitled")
    }

    @Test func searchPrefersRecentWhenScoresAreSimilar() throws {
        let noteA = Note(id: UUID(), title: "Meeting Plan", content: "same body")
        let noteB = Note(id: UUID(), title: "Meeting Plan", content: "same body")

        let result = QuickOpenSearchService.rankedNotes(
            from: [noteA, noteB],
            query: "meeting",
            recentNoteIDs: [noteB.id, noteA.id]
        )

        #expect(result.first?.id == noteB.id)
    }

    @Test func emptyQueryStillPrefersRecentNotes() throws {
        let older = Note(
            id: UUID(),
            title: "Older",
            content: "same",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = Note(
            id: UUID(),
            title: "Newer",
            content: "same",
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let result = QuickOpenSearchService.rankedNotes(
            from: [older, newer],
            query: "",
            recentNoteIDs: [older.id]
        )

        #expect(result.first?.id == older.id)
    }
}

struct MarkdownRendererLinkTests {
    @Test func autoLinksBareHTTPSURLAsNSURL() {
        let url = "https://github.com/ChuenSan/xiaomi10s/actions"
        let rendered = MarkdownRenderer.shared.render("see \(url) now")
        let range = (rendered.string as NSString).range(of: url)
        var effective = NSRange()
        let value = rendered.attribute(.link, at: range.location, effectiveRange: &effective)

        #expect(value as? URL == URL(string: url))
        #expect(effective == range)
    }

    @Test func refreshAutoLinksAppliesWithoutFullRender() {
        let url = "https://github.com/ChuenSan/xiaomi10s/actions"
        let storage = NSMutableAttributedString(string: url)
        MarkdownRenderer.shared.refreshAutoLinks(in: storage)

        #expect(storage.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: url))
    }

    @Test func refreshAutoLinksRemovesStaleLinkAfterEdit() {
        let storage = NSMutableAttributedString(string: "https://github.com/ChuenSan/xiaomi10s/actions")
        MarkdownRenderer.shared.refreshAutoLinks(in: storage)
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "not a link")
        MarkdownRenderer.shared.refreshAutoLinks(in: storage)

        #expect(storage.attribute(.link, at: 0, effectiveRange: nil) == nil)
    }

    @Test func refreshAutoLinksKeepsMarkdownLinks() {
        let url = "https://github.com/ChuenSan/xiaomi10s/actions"
        let rendered = MarkdownRenderer.shared.render("[docs](\(url))")
        let storage = NSMutableAttributedString(attributedString: rendered)
        MarkdownRenderer.shared.refreshAutoLinks(in: storage)

        #expect(storage.string == "docs")
        #expect(storage.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: url))
    }

    @Test func doesNotLinkURLInsideInlineCode() {
        let url = "https://github.com/ChuenSan/xiaomi10s/actions"
        let rendered = MarkdownRenderer.shared.render("`\(url)`")
        let range = (rendered.string as NSString).range(of: url)

        #expect(range.location != NSNotFound)
        #expect(rendered.attribute(.link, at: range.location, effectiveRange: nil) == nil)
    }

    @Test func doesNotLinkURLInsideFencedCode() {
        let url = "https://github.com/ChuenSan/xiaomi10s/actions"
        let rendered = MarkdownRenderer.shared.render("```\n\(url)\n```")
        let range = (rendered.string as NSString).range(of: url)

        #expect(range.location != NSNotFound)
        #expect(rendered.attribute(.link, at: range.location, effectiveRange: nil) == nil)
    }

    @Test func ignoresMailtoAndBareEmail() {
        let rendered = MarkdownRenderer.shared.render("mail me@x.com mailto:me@x.com")
        var foundLink = false
        rendered.enumerateAttribute(.link, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if value != nil { foundLink = true }
        }
        #expect(!foundLink)
    }

    @Test func urlFromLinkOnlyAllowsHTTPSchemes() {
        #expect(MarkdownRenderer.url(from: "mailto:me@x.com") == nil)
        #expect(MarkdownRenderer.url(from: URL(string: "mailto:me@x.com")!) == nil)
        #expect(MarkdownRenderer.url(from: "https://github.com/ChuenSan/xiaomi10s/actions") == URL(string: "https://github.com/ChuenSan/xiaomi10s/actions"))
    }
}

struct SlashCommandTests {
    @Test func dateCommandResolvesCurrentDate() throws {
        let formatter = ISO8601DateFormatter()
        let fixedDate = formatter.date(from: "2026-02-12T12:00:00Z")!
        let dateCommand = SlashCommand.allCommands.first { $0.trigger == "date" }!

        let output = dateCommand.resolvedTemplate(referenceDate: fixedDate)
        #expect(output == "2026-02-12")
    }

    @Test func dailyTemplateResolvesDatePlaceholder() throws {
        let formatter = ISO8601DateFormatter()
        let fixedDate = formatter.date(from: "2026-02-12T12:00:00Z")!
        let dailyCommand = SlashCommand.allCommands.first { $0.trigger == "daily" }!

        let output = dailyCommand.resolvedTemplate(referenceDate: fixedDate)
        #expect(output.contains("Date: 2026-02-12"))
        #expect(output.contains(SlashCommand.cursorMarker))
    }
}

actor StorageTestLock {
    static let shared = StorageTestLock()

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        try await operation()
    }
}

struct FileStorageServiceTests {
    @Test func roundTripsTitleContainingColon() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, _ in
                let note = Note(
                    title: "计划: 第一周",
                    content: "first line\nsecond line"
                )

                try await service.saveNote(note)
                let loaded = try await service.loadAllNotes()
                let reloaded = try #require(loaded.first(where: { $0.id == note.id }))

                #expect(reloaded.title == note.title)
                #expect(reloaded.content == note.content)
            }
        }
    }

    @Test func keepsUniqueFilesForSameTitleAndRapidRename() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                var first = Note(title: "Same Title", content: "alpha")
                let second = Note(title: "Same Title", content: "beta")

                try await service.saveNote(first)
                try await service.saveNote(second)

                first.title = "Renamed Once"
                first.content = "alpha 1"
                first.updatedAt = Date()
                try await service.saveNote(first)

                first.title = "Same Title"
                first.content = "alpha 2"
                first.updatedAt = Date()
                try await service.saveNote(first)

                first.title = "Final Title"
                first.content = "alpha 3"
                first.updatedAt = Date()
                try await service.saveNote(first)

                let files = try markdownFiles(in: directory)
                #expect(files.count == 2)

                let loaded = try await service.loadAllNotes()
                #expect(loaded.contains(where: { $0.id == first.id && $0.title == "Final Title" }))
                #expect(loaded.contains(where: { $0.id == second.id && $0.title == "Same Title" }))
            }
        }
    }

    @Test func deleteAfterRenameRemovesCurrentFile() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                var note = Note(title: "Draft", content: "keep")
                try await service.saveNote(note)

                note.title = "Draft Updated"
                note.updatedAt = Date()
                try await service.saveNote(note)

                try await service.deleteNote(note)

                let files = try markdownFiles(in: directory)
                #expect(files.isEmpty)
            }
        }
    }

    @Test func loadsLegacyUnquotedTitleWithColon() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                let id = UUID()
                let createdAt = ISO8601DateFormatter().string(from: Date())
                let legacy = """
                ---
                title: Legacy: Note Title
                id: \(id.uuidString)
                createdAt: \(createdAt)
                updatedAt: \(createdAt)
                ---

                legacy body
                """

                let fileURL = directory.appendingPathComponent("legacy.md")
                try legacy.write(to: fileURL, atomically: true, encoding: .utf8)

                let loaded = try await service.loadAllNotes()
                let note = try #require(loaded.first(where: { $0.id == id }))
                #expect(note.title == "Legacy: Note Title")
                #expect(note.content == "legacy body")
            }
        }
    }

    @Test func skipsWriteWhenOnlyNormalizedTitleOrLineEndingsDiffer() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                let baseline = Note(
                    id: UUID(),
                    title: "Plan",
                    content: "line1\nline2",
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 200)
                )
                try await service.saveNote(baseline)

                let normalizedEquivalent = Note(
                    id: baseline.id,
                    title: "  Plan  ",
                    content: "line1\r\nline2",
                    createdAt: baseline.createdAt,
                    updatedAt: Date(timeIntervalSince1970: 999)
                )
                try await service.saveNote(normalizedEquivalent)

                let files = try markdownFiles(in: directory)
                #expect(files.count == 1)

                let loaded = try await service.loadAllNotes()
                let saved = try #require(loaded.first(where: { $0.id == baseline.id }))
                #expect(saved.title == baseline.title)
                #expect(saved.content == baseline.content)
                #expect(saved.updatedAt == baseline.updatedAt)
            }
        }
    }

    private func withIsolatedStorage(
        _ operation: (FileStorageService, URL) async throws -> Void
    ) async throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("open-sidenotes-tests-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let service = FileStorageService(volatileStorageDirectory: temporaryDirectory)

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        _ = try await service.loadAllNotes()
        try await operation(service, temporaryDirectory)
    }

    private func markdownFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "md" }
    }
}

struct PanelLayoutTests {
    private let screen = NSRect(x: 100, y: 50, width: 1440, height: 900)

    @Test func defaultSizeFillsVisibleHeightAndUsesDefaultWidth() {
        let frame = PanelLayout.frame(
            in: screen,
            width: PanelLayout.defaultWidth,
            heightRatio: PanelLayout.defaultHeightRatio,
            verticalOffset: PanelLayout.defaultVerticalOffset,
            shown: true
        )

        #expect(frame.width == 400)
        #expect(frame.height == 900)
        #expect(frame.minX == 100)
        #expect(frame.minY == 50)
    }

    @Test func hiddenFrameSlidesLeftByPanelWidth() {
        let frame = PanelLayout.frame(
            in: screen,
            width: 400,
            heightRatio: 1,
            verticalOffset: 0.5,
            shown: false
        )

        #expect(frame.minX == 100 - 400)
        #expect(frame.height == 900)
    }

    @Test func reducedHeightPinsToBottomCenterAndTop() {
        let bottom = PanelLayout.frame(in: screen, width: 400, heightRatio: 0.5, verticalOffset: 0, shown: true)
        let center = PanelLayout.frame(in: screen, width: 400, heightRatio: 0.5, verticalOffset: 0.5, shown: true)
        let top = PanelLayout.frame(in: screen, width: 400, heightRatio: 0.5, verticalOffset: 1, shown: true)

        #expect(bottom.height == 450)
        #expect(bottom.minY == 50)
        #expect(center.minY == 50 + 225)
        #expect(top.maxY == screen.maxY)
    }

    @Test func clampsWidthAndHeightRatioToAllowedRange() {
        let narrow = PanelLayout.frame(in: screen, width: 100, heightRatio: 0.1, verticalOffset: -1, shown: true)
        let wide = PanelLayout.frame(in: screen, width: 999, heightRatio: 2, verticalOffset: 2, shown: true)

        #expect(narrow.width == CGFloat(PanelLayout.widthRange.lowerBound))
        #expect(narrow.height == 320)
        #expect(narrow.minY == 50)
        #expect(wide.width == CGFloat(PanelLayout.widthRange.upperBound))
        #expect(wide.height == 900)
        #expect(wide.minY == 50)
    }

    @Test func fullHeightActivationAcceptsEntireLeftEdge() {
        #expect(isActivation(NSPoint(x: 101, y: 50), heightRatio: 1, offset: 0.5))
        #expect(isActivation(NSPoint(x: 102, y: 500), heightRatio: 1, offset: 0.5))
        #expect(isActivation(NSPoint(x: 100, y: 950), heightRatio: 1, offset: 0.5))
    }

    @Test func reducedHeightActivationIgnoresLeftEdgeOutsidePanel() {
        #expect(isActivation(NSPoint(x: 101, y: 50), heightRatio: 0.5, offset: 0))
        #expect(!isActivation(NSPoint(x: 101, y: 600), heightRatio: 0.5, offset: 0))

        #expect(isActivation(NSPoint(x: 101, y: 275), heightRatio: 0.5, offset: 0.5))
        #expect(!isActivation(NSPoint(x: 101, y: 50), heightRatio: 0.5, offset: 0.5))
        #expect(!isActivation(NSPoint(x: 101, y: 950), heightRatio: 0.5, offset: 0.5))

        #expect(isActivation(NSPoint(x: 101, y: 950), heightRatio: 0.5, offset: 1))
        #expect(!isActivation(NSPoint(x: 101, y: 50), heightRatio: 0.5, offset: 1))
    }

    @Test func activationRequiresLeftEdgeEvenInsidePanelHeight() {
        #expect(!isActivation(NSPoint(x: 103, y: 275), heightRatio: 0.5, offset: 0.5))
        #expect(!isActivation(NSPoint(x: 300, y: 275), heightRatio: 0.5, offset: 0.5))
    }

    private func isActivation(_ point: NSPoint, heightRatio: Double, offset: Double) -> Bool {
        PanelLayout.containsActivationPoint(
            point,
            in: screen,
            width: 400,
            heightRatio: heightRatio,
            verticalOffset: offset
        )
    }
}
