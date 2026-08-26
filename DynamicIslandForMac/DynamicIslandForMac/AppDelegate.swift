import Cocoa
import Combine
import SwiftUI

final class NotchWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        if (NSApp.delegate as? AppDelegate)?.islandState.isRelocating == true
            || (NSApp.delegate as? AppDelegate)?.islandState.placement != .home {
            return frameRect
        }
        if NotchGeometry.keepsOwnerLayout {
            return super.constrainFrameRect(frameRect, to: screen)
        }
        return frameRect
    }
}

final class LyricsPanelWindow: NSWindow {
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        if (NSApp.delegate as? AppDelegate)?.lyrics.isResizing == true
            || (NSApp.delegate as? AppDelegate)?.playlist.isResizing == true {
            return frameRect
        }
        guard let screen = screen ?? self.screen ?? NSScreen.main else { return frameRect }
        var frame = frameRect
        let visible = screen.visibleFrame
        if frame.width > visible.width { frame.size.width = visible.width }
        if frame.height > visible.height { frame.size.height = visible.height }
        if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
        if frame.minX < visible.minX { frame.origin.x = visible.minX }
        if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
        if frame.minY < visible.minY { frame.origin.y = visible.minY }
        return frame
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var notchWindow: NSWindow!
    var hostingView: PillHostingView<IslandView>!
    var statusItem: NSStatusItem!
    let hoverMonitor = NotchHoverMonitor()
    let relocator = IslandRelocator()

    let islandState = IslandState()
    let nowPlaying = NowPlayingManager()
    let timerManager = IslandTimerManager()
    let timerNotifier = TimerFinishNotifier()
    let permissions = PermissionGate()
    let clipboard = ClipboardHistory()
    let lyrics = LyricsManager()
    let playlist = PlaylistManager()
    let audioOutput = AudioOutputManager()
    let micMute = MicMuteManager()
    let guide = IslandGuide()

    var lyricsWindow: NSWindow?
    private var playlistWindow: NSWindow?
    private var guideWindow: NSWindow?
    private var guideHost: GuideHostingView?
    private var lyricsCancellables = Set<AnyCancellable>()
    private var playlistCancellables = Set<AnyCancellable>()
    private var guideCancellables = Set<AnyCancellable>()
    private var guideKeyMonitor: Any?
    private let lyricsWindowDelegate = LyricsWindowDelegate()
    private let playlistWindowDelegate = PlaylistWindowDelegate()
    private let lyricsGap: CGFloat = 22

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotchGeometry.refreshCache()

        timerNotifier.attachAsDelegate()
        timerManager.onFinish = { [weak self] in
            guard let self else { return }
            let resumeMusic = self.nowPlaying.isPlaying
            if resumeMusic {
                self.nowPlaying.pausePlayback()
            }
            self.islandState.pulse()
            self.timerNotifier.announceFinish {
                if resumeMusic {
                    self.nowPlaying.resumePlayback()
                }
            }
        }

        lyrics.start(nowPlaying: nowPlaying)
        playlist.start(nowPlaying: nowPlaying)
        guide.bind(state: islandState, lyrics: lyrics, playlist: playlist, nowPlaying: nowPlaying, relocator: relocator)
        setupStatusItem()
        setupNotchWindow()
        setupLyricsWindow()
        setupPlaylistWindow()
        setupGuideWindow()
        hoverMonitor.onHoveringChange = { [weak self] hovering in
            guard let self else { return }
            if self.islandState.isRelocating {
                self.notchWindow.ignoresMouseEvents = false
                return
            }
            self.notchWindow.ignoresMouseEvents = !hovering
        }
        hoverMonitor.extraStayInside = { [weak self] in
            guard let self else { return false }
            if self.islandState.isEditing { return true }
            if self.relocator.isHolding || self.islandState.isRelocating {
                return true
            }
            let point = NSEvent.mouseLocation
            if self.lyrics.isOpen, let window = self.lyricsWindow, window.isVisible, window.frame.contains(point) {
                return true
            }
            if self.playlist.isOpen, let window = self.playlistWindow, window.isVisible, window.frame.contains(point) {
                return true
            }
            if self.islandState.guideHold != .off { return true }
            if self.islandState.isHovering, let screen = NotchGeometry.targetScreen {
                let chrome = NotchGeometry.editChromeScreenFrame(
                    expanded: true,
                    activity: self.islandState.showsActivity,
                    expandedHeight: self.islandState.expandedHeight,
                    collapsed: self.islandState.collapsedSize,
                    placement: self.islandState.placement,
                    along: self.islandState.along,
                    editing: self.islandState.isEditing,
                    on: screen
                )
                if chrome.contains(point) { return true }
            }
            return false
        }
        hoverMonitor.start(state: islandState)
        relocator.start(window: notchWindow, state: islandState)
        relocator.onMove = { [weak self] in
            self?.repositionWindow()
        }
        permissions.requestEverything()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 18)
        let icon = NSImage(
            systemSymbolName: "circle.fill",
            accessibilityDescription: "Dynamic Island"
        )?.withSymbolConfiguration(.init(pointSize: 7, weight: .regular))
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        permissions.refreshQuietly()
        menu.removeAllItems()

        let machine = NSMenuItem(title: NotchGeometry.machineSummary, action: nil, keyEquivalent: "")
        machine.isEnabled = false
        menu.addItem(machine)

        menu.addItem(.separator())

        let header = NSMenuItem(title: "Доступы для обложек и таймера", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(statusLine("Уведомления", permissions.notifications))
        menu.addItem(statusLine("Музыка", permissions.music))
        menu.addItem(statusLine("Spotify", permissions.spotify))

        menu.addItem(.separator())

        let askAgain = NSMenuItem(title: "Запросить снова", action: #selector(askPermissionsAgain), keyEquivalent: "")
        askAgain.target = self
        menu.addItem(askAgain)

        let settings = NSMenuItem(title: "Открыть настройки Автоматизации…", action: #selector(openAutomationSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        if permissions.notifications == .denied {
            let notify = NSMenuItem(title: "Открыть настройки уведомлений…", action: #selector(openNotificationSettings), keyEquivalent: "")
            notify.target = self
            menu.addItem(notify)
        }

        menu.addItem(.separator())

        let editItem = NSMenuItem(title: "Редакт островка", action: #selector(beginIslandEdit), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)

        let stopGuide = NSMenuItem(title: "Закрыть гид", action: #selector(stopIslandGuide), keyEquivalent: ".")
        stopGuide.target = self
        stopGuide.keyEquivalentModifierMask = [.command]
        stopGuide.isEnabled = guide.isActive
        menu.addItem(stopGuide)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func statusLine(_ name: String, _ status: PermissionGate.Status) -> NSMenuItem {
        let item = NSMenuItem(title: "\(name): \(status.menuLabel)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func askPermissionsAgain() {
        permissions.requestEverything()
        permissions.requestAutomation(prompt: true)
    }

    @objc private func openAutomationSettings() {
        permissions.openAutomationSettings()
    }

    @objc private func openNotificationSettings() {
        permissions.openNotificationSettings()
    }

    @objc private func beginIslandEdit() {
        islandState.beginEditing()
        notchWindow.ignoresMouseEvents = false
    }

    @objc private func stopIslandGuide() {
        guide.stop()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setupNotchWindow() {
        guard let screen = NotchGeometry.targetScreen else { return }
        islandState.collapsedSize = NotchGeometry.collapsedSize(for: screen)
        let frame = NotchGeometry.windowFrame(for: screen, state: islandState, mouse: nil)

        let window = NotchWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setFrame(frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 3)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = false
        window.ignoresMouseEvents = true

        let rootView = IslandView(
            state: islandState,
            nowPlaying: nowPlaying,
            timerManager: timerManager,
            clipboard: clipboard,
            lyrics: lyrics,
            playlist: playlist,
            audioOutput: audioOutput,
            micMute: micMute,
            guide: guide
        )
        let hosting = PillHostingView(rootView: rootView)
        hosting.state = islandState
        hosting.frame = NSRect(origin: .zero, size: frame.size)

        window.contentView = hosting
        window.orderFrontRegardless()
        self.notchWindow = window
        self.hostingView = hosting

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NotchGeometry.refreshCache()
            self?.repositionWindow()
        }
    }

    private func repositionWindow() {
        guard let screen = NotchGeometry.targetScreen else { return }
        islandState.collapsedSize = NotchGeometry.collapsedSize(for: screen)
        let frame = NotchGeometry.windowFrame(
            for: screen,
            state: islandState,
            mouse: islandState.isRelocating ? (relocator.followPoint ?? NSEvent.mouseLocation) : nil
        )
        notchWindow.setFrame(frame, display: true)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        applyLyricsWindowFrame()
        applyPlaylistWindowFrame()
        applyGuideWindowFrame()
        relocator.updateHomeWindow()
    }

    private func setupGuideWindow() {
        let host = GuideHostingView(
            rootView: GuideOverlayView(guide: guide) { [weak self] hole, card in
                self?.guideHost?.hole = hole
                self?.guideHost?.card = card
            }
        )
        guideHost = host
        let window = GuidePanelWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        window.alphaValue = 0
        window.contentView = host
        window.orderOut(nil)
        guideWindow = window

        guide.$isActive
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.setGuideWindowVisible(active)
            }
            .store(in: &guideCancellables)

        if guideKeyMonitor == nil {
            guideKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53, self?.guide.isActive == true {
                    self?.guide.skip()
                    return nil
                }
                return event
            }
        }

        islandState.$guideHold
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionWindow()
            }
            .store(in: &guideCancellables)

        islandState.$placement
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionWindow()
            }
            .store(in: &guideCancellables)
    }

    private func setGuideWindowVisible(_ visible: Bool) {
        guard let guideWindow else { return }
        if visible {
            applyGuideWindowFrame()
            guideWindow.alphaValue = 1
            guideWindow.orderFrontRegardless()
            notchWindow.ignoresMouseEvents = false
        } else {
            guideWindow.alphaValue = 0
            guideWindow.orderOut(nil)
            guideHost?.hole = .null
            guideHost?.card = .null
        }
    }

    private func applyGuideWindowFrame() {
        guard let guideWindow, let screen = NotchGeometry.targetScreen else { return }
        guideWindow.setFrame(screen.frame, display: true)
        guideHost?.frame = NSRect(origin: .zero, size: screen.frame.size)
    }

    private func setupLyricsWindow() {
        let host = LyricsHostingView(rootView: LyricsView(lyrics: lyrics, nowPlaying: nowPlaying, guide: guide))
        host.frame = NSRect(origin: .zero, size: lyrics.panelSize)

        let window = LyricsPanelWindow(
            contentRect: NSRect(origin: .zero, size: lyrics.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = true
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.contentView = host
        window.delegate = lyricsWindowDelegate
        window.orderOut(nil)
        lyricsWindow = window

        lyrics.$isOpen
            .combineLatest(lyrics.$available, guide.$forceLyricsPanel)
            .receive(on: RunLoop.main)
            .sink { [weak self] open, available, force in
                self?.setLyricsWindowVisible((open && available) || force)
            }
            .store(in: &lyricsCancellables)

        lyrics.onLiveFrame = { [weak self] in
            self?.applyLyricsWindowFrame()
        }
    }

    private func setLyricsWindowVisible(_ visible: Bool) {
        guard let lyricsWindow, let target = lyricsFrame() else { return }
        if visible {
            let appearing = !lyricsWindow.isVisible || lyricsWindow.alphaValue < 0.05
            if appearing {
                var start = target
                start.origin.y -= 10
                lyricsWindow.ignoresMouseEvents = false
                lyricsWindow.setFrame(start, display: true)
                lyricsWindow.alphaValue = 0
                lyricsWindow.orderFrontRegardless()
                animateLyricsWindow {
                    lyricsWindow.animator().alphaValue = 1
                    lyricsWindow.animator().setFrame(target, display: true)
                }
            } else {
                lyricsWindow.ignoresMouseEvents = false
                lyricsWindow.setFrame(target, display: true, animate: false)
                lyricsWindow.contentView?.frame = NSRect(origin: .zero, size: target.size)
            }
            if !guide.forceLyricsPanel, !lyrics.userPlaced {
                lyrics.userPlaced = true
                lyrics.rememberOrigin(target.origin)
            }
        } else if lyricsWindow.isVisible {
            animateLyricsWindow({
                lyricsWindow.animator().alphaValue = 0
            }, completion: { [weak self] in
                guard let self, !self.lyrics.isOpen || !self.lyrics.available else { return }
                lyricsWindow.ignoresMouseEvents = true
                lyricsWindow.orderOut(nil)
            })
        }
    }

    private func applyLyricsWindowFrame() {
        guard lyricsWindow?.isVisible == true, (lyricsWindow?.alphaValue ?? 0) > 0.05 else { return }
        guard let lyricsWindow, let target = lyricsFrame() else { return }
        lyricsWindow.setFrame(target, display: true, animate: false)
        lyricsWindow.contentView?.frame = NSRect(origin: .zero, size: target.size)
    }

    private func lyricsFrame() -> NSRect? {
        guard let screen = NotchGeometry.targetScreen else { return nil }
        let size = lyrics.panelSize
        if lyrics.isResizing {
            return NSRect(
                x: lyrics.pinnedLeft,
                y: lyrics.pinnedTop - size.height,
                width: size.width,
                height: size.height
            )
        }
        if !guide.forceLyricsPanel, lyrics.userPlaced, let origin = lyrics.panelOrigin,
           !lyricsOriginIsParkedAtBottom(origin, size: size, on: screen) {
            return NSRect(origin: origin, size: size)
        }
        let pill = NotchGeometry.pillScreenFrame(
            expanded: islandState.isExpanded || guide.forceLyricsPanel,
            activity: islandState.showsActivity,
            expandedHeight: islandState.expandedHeight,
            collapsed: islandState.collapsedSize,
            placement: islandState.dockedPlacement,
            along: islandState.along,
            on: screen
        )
        return NotchGeometry.accessoryFrame(
            size: size,
            gap: lyricsGap,
            offsetX: 0,
            pill: pill,
            placement: islandState.dockedPlacement
        )
    }

    private func lyricsOriginIsParkedAtBottom(_ origin: CGPoint, size: CGSize, on screen: NSScreen) -> Bool {
        guard islandState.dockedPlacement == .home else { return false }
        let visible = screen.visibleFrame
        return origin.y < visible.minY + visible.height * 0.38
    }

    private func animateLyricsWindow(_ changes: () -> Void, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.42
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.86, 0.32, 1)
            context.allowsImplicitAnimation = false
            changes()
        }, completionHandler: completion)
    }

    private func setupPlaylistWindow() {
        let host = PlaylistHostingView(rootView: PlaylistView(playlist: playlist, guide: guide))
        host.frame = NSRect(origin: .zero, size: playlist.panelSize)

        let window = LyricsPanelWindow(
            contentRect: NSRect(origin: .zero, size: playlist.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = true
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.contentView = host
        window.delegate = playlistWindowDelegate
        window.orderOut(nil)
        playlistWindow = window

        playlist.$isOpen
            .combineLatest(playlist.$available)
            .receive(on: RunLoop.main)
            .sink { [weak self] open, available in
                self?.setPlaylistWindowVisible(open && available)
            }
            .store(in: &playlistCancellables)

        playlist.onLiveFrame = { [weak self] in
            self?.applyPlaylistWindowFrame()
        }
    }

    private func setPlaylistWindowVisible(_ visible: Bool) {
        guard let playlistWindow, let target = playlistFrame() else { return }
        if visible {
            let appearing = !playlistWindow.isVisible || playlistWindow.alphaValue < 0.05
            guard appearing else { return }
            var start = target
            start.origin.y -= 10
            playlistWindow.ignoresMouseEvents = false
            playlistWindow.setFrame(start, display: true)
            playlistWindow.alphaValue = 0
            playlistWindow.orderFrontRegardless()
            animateLyricsWindow {
                playlistWindow.animator().alphaValue = 1
                playlistWindow.animator().setFrame(target, display: true)
            }
            if !playlist.userPlaced {
                playlist.userPlaced = true
                playlist.rememberOrigin(target.origin)
            }
        } else if playlistWindow.isVisible {
            animateLyricsWindow({
                playlistWindow.animator().alphaValue = 0
            }, completion: { [weak self] in
                guard let self, !self.playlist.isOpen || !self.playlist.available else { return }
                playlistWindow.ignoresMouseEvents = true
                playlistWindow.orderOut(nil)
            })
        }
    }

    private func applyPlaylistWindowFrame() {
        guard playlistWindow?.isVisible == true, (playlistWindow?.alphaValue ?? 0) > 0.05 else { return }
        guard let playlistWindow, let target = playlistFrame() else { return }
        playlistWindow.setFrame(target, display: true, animate: false)
        playlistWindow.contentView?.frame = NSRect(origin: .zero, size: target.size)
    }

    private func playlistFrame() -> NSRect? {
        guard let screen = NotchGeometry.targetScreen else { return nil }
        let size = playlist.panelSize
        if playlist.isResizing {
            return NSRect(
                x: playlist.pinnedLeft,
                y: playlist.pinnedTop - size.height,
                width: size.width,
                height: size.height
            )
        }
        if playlist.userPlaced, let origin = playlist.panelOrigin {
            return NSRect(origin: origin, size: size)
        }
        let pill = NotchGeometry.pillScreenFrame(
            expanded: islandState.isExpanded,
            activity: islandState.showsActivity,
            expandedHeight: islandState.expandedHeight,
            collapsed: islandState.collapsedSize,
            placement: islandState.dockedPlacement,
            along: islandState.along,
            on: screen
        )
        return NotchGeometry.accessoryFrame(
            size: size,
            gap: lyricsGap,
            offsetX: islandState.dockedPlacement == .left || islandState.dockedPlacement == .right ? 0 : 36,
            pill: pill,
            placement: islandState.dockedPlacement
        )
    }
}

private final class LyricsWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let app = NSApp.delegate as? AppDelegate else { return }
        guard app.lyrics.userPlaced, !app.lyrics.isResizing else { return }
        app.lyrics.rememberOrigin(window.frame.origin)
        app.lyrics.persistPanel()
    }
}

private final class PlaylistWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let app = NSApp.delegate as? AppDelegate else { return }
        guard app.playlist.userPlaced, !app.playlist.isResizing else { return }
        app.playlist.rememberOrigin(window.frame.origin)
        app.playlist.persistPanel()
    }
}
