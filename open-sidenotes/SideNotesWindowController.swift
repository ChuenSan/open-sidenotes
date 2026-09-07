import Cocoa
import SwiftUI

enum PanelLayout {
    static let widthRange: ClosedRange<Double> = 280...560
    static let heightRatioRange: ClosedRange<Double> = 0.4...1.0
    static let verticalOffsetRange: ClosedRange<Double> = 0...1
    static let defaultWidth: Double = 400
    static let defaultHeightRatio: Double = 1.0
    static let defaultVerticalOffset: Double = 0.5
    static let minHeight: CGFloat = 320

    static func frame(
        in visibleFrame: NSRect,
        width: Double,
        heightRatio: Double,
        verticalOffset: Double,
        shown: Bool
    ) -> NSRect {
        let panelWidth = CGFloat(min(widthRange.upperBound, max(widthRange.lowerBound, width)))
        let ratio = min(heightRatioRange.upperBound, max(heightRatioRange.lowerBound, heightRatio))
        let height = min(visibleFrame.height, max(minHeight, visibleFrame.height * CGFloat(ratio)))
        let offset = min(verticalOffsetRange.upperBound, max(verticalOffsetRange.lowerBound, verticalOffset))
        let y = visibleFrame.minY + (visibleFrame.height - height) * CGFloat(offset)
        let x = shown ? visibleFrame.minX : visibleFrame.minX - panelWidth
        return NSRect(x: x, y: y, width: panelWidth, height: height)
    }
}

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SideNotesWindowController: NSWindowController {
    private var pollTimer: Timer?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var isShown = false
    private var lastAtLeftEdge = false
    private var hideTimer: Timer?
    private var dummyWindow: NSWindow?
    private var isAnimating = false
    private var trackingArea: NSTrackingArea?
    private let settings = ShortcutSettings.shared

    init() {
        let visibleFrame = NSScreen.main!.visibleFrame
        let initialSettings = ShortcutSettings.shared
        let hiddenFrame = PanelLayout.frame(
            in: visibleFrame,
            width: initialSettings.panelWidth,
            heightRatio: initialSettings.panelHeightRatio,
            verticalOffset: initialSettings.panelVerticalOffset,
            shown: false
        )
        let window = KeyableWindow(
            contentRect: hiddenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: hiddenFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView

        super.init(window: window)

        setupDummyWindow()
        setupEventMonitors()
        setupTrackingArea()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelSizeSettingChanged),
            name: .panelSizeSettingChanged,
            object: nil
        )
    }

    private func setupDummyWindow() {
        let dummy = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        dummy.isOpaque = false
        dummy.backgroundColor = .clear
        dummy.alphaValue = 0
        dummy.ignoresMouseEvents = true
        dummy.level = .floating
        dummy.collectionBehavior = [.stationary, .ignoresCycle]
        dummy.orderBack(nil)
        dummyWindow = dummy
    }

    private func setupEventMonitors() {
        // Global mouse-moved monitors receive no events while this app is active,
        // so edge detection would silently die after auto-hide closes the window.
        // Polling NSEvent.mouseLocation works regardless of activation state.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.handleMouseMove()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClickOutside(event)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
    }

    private func setupTrackingArea() {
        guard let contentView = window?.contentView else { return }

        trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea!)
    }

    override func mouseExited(with event: NSEvent) {
        if isShown && settings.autoHideOnMouseExit {
            if settings.hideDelay == 0 {
                hideWindow()
            } else {
                startHideTimer()
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        cancelHideTimer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hideTimer?.invalidate()
        pollTimer?.invalidate()

        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        if let trackingArea = trackingArea, let contentView = window?.contentView {
            contentView.removeTrackingArea(trackingArea)
        }
    }

    private func handleMouseMove() {
        let mouseLocation = NSEvent.mouseLocation
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        let atLeftEdge = mouseLocation.x <= visibleFrame.minX + 2

        if atLeftEdge && (!lastAtLeftEdge || !isShown) {
            if !isShown {
                showWindow()
            }
            cancelHideTimer()
        } else if isShown && !isMouseInWindow() && !isAnimating && settings.autoHideOnMouseExit {
            startHideTimer()
        }

        lastAtLeftEdge = atLeftEdge
    }

    private func handleClickOutside(_ event: NSEvent) {
        if isShown && !isMouseInWindow() {
            hideWindow()
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 && isShown {
            hideWindow()
        }
    }

    private func isMouseInWindow() -> Bool {
        guard let window = self.window else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        return windowFrame.contains(mouseLocation)
    }

    private func startHideTimer() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: settings.hideDelay, repeats: false) { [weak self] _ in
            if self?.isShown == true && self?.isMouseInWindow() == false {
                self?.hideWindow()
            }
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func currentFrame(in visibleFrame: NSRect, shown: Bool) -> NSRect {
        PanelLayout.frame(
            in: visibleFrame,
            width: settings.panelWidth,
            heightRatio: settings.panelHeightRatio,
            verticalOffset: settings.panelVerticalOffset,
            shown: shown
        )
    }

    @objc private func panelSizeSettingChanged() {
        guard isShown, !isAnimating, let window = window, let visibleFrame = NSScreen.main?.visibleFrame else {
            return
        }
        window.setFrame(currentFrame(in: visibleFrame, shown: true), display: true)
    }

    private func showWindow() {
        guard let window = self.window, !isShown, !isAnimating else { return }
        isShown = true
        isAnimating = true
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        window.setFrame(currentFrame(in: visibleFrame, shown: false), display: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(currentFrame(in: visibleFrame, shown: true), display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
    }

    private func hideWindow() {
        guard let window = self.window, isShown, !isAnimating else { return }
        isShown = false
        isAnimating = true
        NotificationCenter.default.post(name: .flushActiveNoteDraft, object: nil)
        cancelHideTimer()
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(currentFrame(in: visibleFrame, shown: false), display: true)
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.isAnimating = false
        })
    }

    func toggleWindow() {
        if isShown {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindowFromDock() {
        toggleWindow()
    }
}
