import AppKit
import SwiftUI

final class IslandRelocator {

    weak var window: NSWindow?
    weak var state: IslandState?
    var onMove: (() -> Void)?
    private(set) var isHolding = false

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var timer: Timer?
    private var clickTimes: [TimeInterval] = []
    private var lastClickStamp: TimeInterval = 0
    private var relocateOrigin: CGPoint?
    private var savedPlacement: IslandPlacement = .home
    private var savedAlong: CGFloat = 0.5
    private var homeWindow: NSWindow?
    private var ignoreStartUp = false
    private var dropReadyAt: TimeInterval = 0
    private var lastFollowTime: TimeInterval = 0
    private(set) var followPoint: NSPoint?
    private var isFlying = false
    private var flyFrom: NSPoint?
    private var flyTo: NSPoint?
    private var flyStart: TimeInterval = 0
    private var flyDuration: TimeInterval = 0
    private var pendingSnap: (IslandPlacement, CGFloat)?
    /// After enter-relocate clicks, ignore attach clicks for this long so a fast triple-click can free the island.
    private let dropGrace: TimeInterval = 2.0

    func start(window: NSWindow, state: IslandState) {
        self.window = window
        self.state = state
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
        }
        updateHomeWindow()
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        stopFollowTimer()
    }

    func goHome() {
        guard let state else { return }
        resetClicks()
        cancelFly()
        state.goHome()
        followPoint = nil
        stopFollowTimer()
        window?.ignoresMouseEvents = true
        applyFrame()
        updateHomeWindow()
    }

    func updateHomeWindow() {
        guard let state, let screen = NotchGeometry.targetScreen else { return }
        let show = state.placement != .home && !state.isRelocating
        if show {
            let frame = NotchGeometry.homeButtonFrame(on: screen)
            let window = homeWindow ?? makeHomeWindow()
            homeWindow = window
            window.setFrame(frame, display: true)
            window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
        } else {
            homeWindow?.orderOut(nil)
        }
    }

    private func tick() {
        guard let state else { return }
        if isFlying {
            isHolding = true
            tickFly()
            return
        }
        if state.isRelocating {
            isHolding = true
            drag(NSEvent.mouseLocation)
            return
        }
        isHolding = false
    }

    private func registerClick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastClickStamp < 0.05 { return }
        lastClickStamp = now
        let window: TimeInterval = 1.5
        clickTimes.append(now)
        clickTimes.removeAll { now - $0 > window }
        if clickTimes.count >= 3 {
            clickTimes = []
            beginRelocating()
        }
    }

    private func isOnIsland(_ state: IslandState) -> Bool {
        guard let screen = NotchGeometry.targetScreen else { return false }
        let point = NSEvent.mouseLocation
        if NotchGeometry.containsCursor(
            point,
            expanded: true,
            activity: state.showsActivity,
            expandedHeight: state.expandedHeight,
            on: screen,
            placement: state.placement,
            along: state.along,
            collapsed: state.collapsedSize
        ) {
            return true
        }
        return NotchGeometry.isOnCollapsedPill(
            point,
            activity: state.showsActivity,
            on: screen,
            placement: state.placement,
            along: state.along
        )
        || NotchGeometry.collapsedPillFrame(
            activity: state.showsActivity,
            on: screen,
            placement: state.placement,
            along: state.along,
            collapsed: state.collapsedSize
        ).insetBy(dx: -16, dy: -16).contains(point)
    }

    private func handle(_ event: NSEvent) {
        guard let state else { return }
        switch event.type {
        case .leftMouseDown:
            if state.isRelocating {
                if isFlying { return }
                if ignoreStartUp { return }
                if ProcessInfo.processInfo.systemUptime < dropReadyAt { return }
                dropAtCursor()
                return
            }
            guard !state.isEditing, isOnIsland(state) else { return }
            registerClick()
            if event.clickCount >= 3 {
                clickTimes = []
                beginRelocating()
            }
        case .leftMouseDragged:
            if state.isRelocating, !isFlying {
                drag(NSEvent.mouseLocation)
            }
        case .leftMouseUp:
            if state.isRelocating, ignoreStartUp {
                ignoreStartUp = false
            }
        default:
            break
        }
    }

    private func resetClicks() {
        clickTimes = []
        isHolding = false
    }

    private func beginRelocating() {
        guard let state, !state.isRelocating, !state.isEditing else { return }
        guard let screen = NotchGeometry.targetScreen else { return }
        resetClicks()
        savedPlacement = state.placement
        savedAlong = state.along
        relocateOrigin = NSEvent.mouseLocation
        ignoreStartUp = true
        dropReadyAt = ProcessInfo.processInfo.systemUptime + dropGrace
        lastFollowTime = ProcessInfo.processInfo.systemUptime
        let pill = NotchGeometry.pillScreenFrame(
            expanded: state.isExpanded,
            activity: state.showsActivity,
            expandedHeight: state.expandedHeight,
            collapsed: state.collapsedSize,
            placement: state.placement,
            along: state.along,
            on: screen
        )
        followPoint = CGPoint(x: pill.midX, y: pill.midY)
        state.magnet = nil
        state.isRelocating = true
        state.isHovering = false
        state.mosesCursor = nil
        state.shakeOffset = 0
        window?.ignoresMouseEvents = false
        startFollowTimer()
        applyFrame()
        updateHomeWindow()
    }

    private func startFollowTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopFollowTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func drag(_ mouse: NSPoint) {
        guard let state, state.isRelocating, !isFlying else { return }
        state.magnet = nil
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(max(now - lastFollowTime, 1.0 / 120.0), 0.05)
        lastFollowTime = now
        let pull = 1 - exp(-dt / 0.055)
        var point = followPoint ?? mouse
        point.x += (mouse.x - point.x) * pull
        point.y += (mouse.y - point.y) * pull
        followPoint = point
        applyFrame()
    }

    private func dropAtCursor() {
        guard let state, state.isRelocating, !isFlying, let screen = NotchGeometry.targetScreen else { return }
        let origin = followPoint ?? NSEvent.mouseLocation
        let target = NotchGeometry.nearestWallTarget(
            from: origin,
            on: screen,
            collapsed: state.collapsedSize
        )
        let distance = hypot(target.center.x - origin.x, target.center.y - origin.y)
        if distance < 6 {
            state.magnet = target.placement
            state.along = target.along
            finishDrag()
            return
        }
        pendingSnap = (target.placement, target.along)
        flyFrom = origin
        flyTo = target.center
        flyStart = ProcessInfo.processInfo.systemUptime
        flyDuration = min(0.48, max(0.18, TimeInterval(distance) / 1700))
        isFlying = true
        startFollowTimer()
    }

    private func tickFly() {
        guard let from = flyFrom, let to = flyTo else {
            cancelFly()
            finishDrag()
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - flyStart
        let t = flyDuration > 0 ? min(max(elapsed / flyDuration, 0), 1) : 1
        followPoint = NSPoint(
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t
        )
        applyFrame()
        if t >= 1 {
            completeFly()
        }
    }

    private func completeFly() {
        if let snap = pendingSnap, let state {
            state.magnet = snap.0
            state.along = snap.1
        }
        cancelFly()
        finishDrag()
    }

    private func cancelFly() {
        isFlying = false
        flyFrom = nil
        flyTo = nil
        flyDuration = 0
        pendingSnap = nil
    }

    private func finishDrag() {
        guard let state else { return }
        resetClicks()
        if let magnet = state.magnet {
            state.placement = magnet
            state.persistPlacement()
        } else {
            state.placement = savedPlacement
            state.along = savedAlong
        }
        state.magnet = nil
        state.isRelocating = false
        state.shakeOffset = 0
        relocateOrigin = nil
        followPoint = nil
        ignoreStartUp = false
        dropReadyAt = 0
        cancelFly()
        stopFollowTimer()
        window?.ignoresMouseEvents = true
        applyFrame()
        updateHomeWindow()
    }

    private func applyFrame() {
        onMove?()
    }

    private func makeHomeWindow() -> NSWindow {
        let host = HomeDockHostingView(
            rootView: HomeDockView { [weak self] in
                self?.goHome()
            }
        )
        host.frame = NSRect(origin: .zero, size: CGSize(width: 22, height: 22))
        let window = HomeDockWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.contentView = host
        return window
    }
}

private final class HomeDockWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class HomeDockHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? super.hitTest(point) : nil
    }
}

private struct HomeDockView: View {
    var onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Image(systemName: "house.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 22, height: 22)
                .background {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Color.black.opacity(0.3))
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                }
        }
        .buttonStyle(.plain)
        .help("Домой")
    }
}
