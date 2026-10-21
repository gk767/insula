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

final class TodoPanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        if (NSApp.delegate as? AppDelegate)?.todo.isResizing == true {
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
    let todo = TodoManager()
    let audioOutput = AudioOutputManager()
    let micMute = MicMuteManager()
    let guide = IslandGuide()
    let scheduleManager = ScheduleManager()
    let scheduleNotifier = ScheduleNotifier()

    var lyricsWindow: NSWindow?
    private var playlistWindow: NSWindow?
    private var todoWindow: NSWindow?
    private var confettiWindow: NSWindow?
    private var scheduleSettingsWindow: NSWindow?
    private var guideWindow: NSWindow?
    private var guideHost: GuideHostingView?
    private var lyricsCancellables = Set<AnyCancellable>()
    private var playlistCancellables = Set<AnyCancellable>()
    private var todoCancellables = Set<AnyCancellable>()
    private var confettiHideWorkItem: DispatchWorkItem?
    private var guideCancellables = Set<AnyCancellable>()
    private var mouseWatchdog: Timer?
    private var guideKeyMonitor: Any?
    private let lyricsWindowDelegate = LyricsWindowDelegate()
    private let playlistWindowDelegate = PlaylistWindowDelegate()
    private let todoWindowDelegate = TodoWindowDelegate()
    private let lyricsGap: CGFloat = 22

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != pid }
        guard let existing = others.first else { return }
        existing.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }

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

        scheduleManager.onNudge = { [weak self] title, body in
            guard let self else { return }
            self.islandState.pulse()
            self.scheduleNotifier.postImmediate(title: title, body: body)
        }
        scheduleManager.refresh()
        scheduleNotifier.reschedule(scheduleManager.notificationItems())

        scheduleManager.objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleNotifier.reschedule(self.scheduleManager.notificationItems())
            }
            .store(in: &guideCancellables)

        lyrics.start(nowPlaying: nowPlaying)
        playlist.start(nowPlaying: nowPlaying)
        guide.bind(state: islandState, lyrics: lyrics, playlist: playlist, nowPlaying: nowPlaying, relocator: relocator)
        setupStatusItem()
        setupNotchWindow()
        setupLyricsWindow()
        setupPlaylistWindow()
        setupTodoWindow()
        setupConfettiWindow()
        setupScheduleSettingsWindow()
        setupGuideWindow()
        hoverMonitor.onHoveringChange = { [weak self] _ in
            guard let self else { return }
            if self.islandState.isRelocating {
                self.notchWindow.ignoresMouseEvents = false
                return
            }
            // Источник правды — не флаг наведения, а «остров раскрыт». Иначе во время
            // правки/гайда окно оставалось с глухой мышью и остров нельзя было закрыть.
            self.notchWindow.ignoresMouseEvents = !(self.islandState.isExpanded || self.islandState.isRelocating)
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
            if self.todo.isOpen, let window = self.todoWindow, window.isVisible, window.frame.contains(point) {
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
        // Страховка на случай рассинхрона: пока остров раскрыт, окно обязано
        // принимать мышь, иначе он «висит» и ничего не нажимается.
        let watchdog = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let wantIgnore = !(self.islandState.isExpanded || self.islandState.isRelocating)
            if self.notchWindow.ignoresMouseEvents != wantIgnore {
                self.notchWindow.ignoresMouseEvents = wantIgnore
            }
        }
        RunLoop.main.add(watchdog, forMode: .common)
        mouseWatchdog = watchdog
        relocator.start(window: notchWindow, state: islandState)
        relocator.onMove = { [weak self] in
            self?.repositionWindow()
        }
        permissions.requestEverything()
        if islandState.shows(.schedule) {
            scheduleManager.requestAccess()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 18)
        let icon = NSImage(
            systemSymbolName: "circle.fill",
            accessibilityDescription: "Insula"
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

        let header = NSMenuItem(title: "Доступы для обложек, таймера и расписания", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(statusLine("Уведомления", permissions.notifications))
        menu.addItem(statusLine("Календарь", permissions.calendar))
        menu.addItem(statusLine("Напоминания", permissions.reminders))
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

        if permissions.calendar == .denied {
            let calendars = NSMenuItem(title: "Открыть настройки календаря…", action: #selector(openCalendarSettings), keyEquivalent: "")
            calendars.target = self
            menu.addItem(calendars)
        }

        if permissions.reminders == .denied {
            let reminders = NSMenuItem(title: "Открыть настройки напоминаний…", action: #selector(openRemindersSettings), keyEquivalent: "")
            reminders.target = self
            menu.addItem(reminders)
        }

        menu.addItem(.separator())

        let editItem = NSMenuItem(
            title: islandState.isEditing ? "Готово — выйти из редакта" : "Редакт Insula",
            action: #selector(beginIslandEdit),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        let todoItem = NSMenuItem(title: "Список дел", action: #selector(openTodoList), keyEquivalent: "")
        todoItem.target = self
        menu.addItem(todoItem)

        let closeItem = NSMenuItem(title: "Закрыть остров", action: #selector(closeIsland), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        let scheduleSettings = NSMenuItem(title: "Календари и напоминания…", action: #selector(openScheduleSettings), keyEquivalent: "")
        scheduleSettings.target = self
        menu.addItem(scheduleSettings)

        let stopGuide = NSMenuItem(title: "Закрыть гид", action: #selector(stopIslandGuide), keyEquivalent: ".")
        stopGuide.target = self
        stopGuide.keyEquivalentModifierMask = [.command]
        stopGuide.isEnabled = guide.isActive
        menu.addItem(stopGuide)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Выключить Insula", action: #selector(quit), keyEquivalent: "q")
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

    @objc private func openCalendarSettings() {
        permissions.openCalendarSettings()
    }

    @objc private func openRemindersSettings() {
        permissions.openRemindersSettings()
    }

    @objc private func openScheduleSettings() {
        scheduleManager.isSettingsOpen = true
    }

    @objc private func openTodoList() {
        todo.isOpen = true
    }

    @objc private func beginIslandEdit() {
        if islandState.isEditing {
            islandState.endEditing()
            notchWindow.ignoresMouseEvents = !islandState.isHovering
        } else {
            islandState.beginEditing()
            notchWindow.ignoresMouseEvents = false
        }
    }

    @objc private func stopIslandGuide() {
        guide.stop()
    }

    /// Аварийный выход: принудительно закрыть остров, чем бы он ни был раскрыт —
    /// наведением, правкой или шагом гайда. Нужен на случай, если окно осталось
    /// с «глухой» мышью и по острову нельзя попасть.
    @objc private func closeIsland() {
        guide.stop()
        islandState.endEditing()
        islandState.isHovering = false
        if islandState.placement != .home {
            islandState.goHome()
        }
        islandState.approachSquish = 0
        notchWindow.ignoresMouseEvents = true
    }

    @objc private func quit() {
        guide.stop()
        lyrics.isOpen = false
        playlist.isOpen = false
        todo.isOpen = false
        islandState.isHovering = false
        islandState.isEditing = false
        islandState.isRelocating = false
        hoverMonitor.stop()
        nowPlaying.shutdown()
        notchWindow.orderOut(nil)
        lyricsWindow?.orderOut(nil)
        playlistWindow?.orderOut(nil)
        todoWindow?.orderOut(nil)
        confettiWindow?.orderOut(nil)
        guideWindow?.orderOut(nil)
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
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
            scheduleManager: scheduleManager,
            clipboard: clipboard,
            lyrics: lyrics,
            playlist: playlist,
            todo: todo,
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
        applyTodoWindowFrame()
        applyGuideWindowFrame()
        relocator.updateHomeWindow()
    }

    private func setupGuideWindow() {
        let host = GuideHostingView(
            rootView: GuideOverlayView(guide: guide) { [weak self] hole, card, escape in
                self?.guideHost?.hole = hole
                self?.guideHost?.card = card
                self?.guideHost?.escape = escape
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
                guard let self else { return event }
                if self.guide.isActive {
                    if event.keyCode == 53 {
                        self.guide.skip()
                        return nil
                    }
                    if event.keyCode == 36 || event.keyCode == 76 {
                        self.guide.next()
                        return nil
                    }
                    return event
                }
                // Запасной выход из редакта: Esc, пока окно ещё принимает клавиши.
                if event.keyCode == 53, self.islandState.isEditing {
                    self.islandState.endEditing()
                    self.notchWindow.ignoresMouseEvents = !self.islandState.isHovering
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
            NSApp.activate(ignoringOtherApps: true)
            guideWindow.makeKeyAndOrderFront(nil)
            guideWindow.orderFrontRegardless()
            notchWindow.ignoresMouseEvents = false
        } else {
            guideWindow.alphaValue = 0
            guideWindow.orderOut(nil)
            guideHost?.hole = .null
            guideHost?.card = .null
            guideHost?.escape = .null
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
        if !guide.forceLyricsPanel, lyrics.userPlaced, let origin = lyrics.panelOrigin {
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

    private func setupTodoWindow() {
        let host = TodoHostingView(rootView: TodoView(todo: todo))
        host.frame = NSRect(origin: .zero, size: todo.panelSize)

        let window = TodoPanelWindow(
            contentRect: NSRect(origin: .zero, size: todo.panelSize),
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
        window.delegate = todoWindowDelegate
        window.orderOut(nil)
        todoWindow = window

        todo.$isOpen
            .receive(on: RunLoop.main)
            .sink { [weak self] open in
                self?.setTodoWindowVisible(open)
            }
            .store(in: &todoCancellables)

        todo.$confettiToken
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.islandState.transportAnimationsOn else { return }
                self.showConfetti()
            }
            .store(in: &todoCancellables)

        todo.onLiveFrame = { [weak self] in
            self?.applyTodoWindowFrame()
        }
    }

    private func setTodoWindowVisible(_ visible: Bool) {
        guard let todoWindow, let target = todoFrame() else { return }
        if visible {
            let appearing = !todoWindow.isVisible || todoWindow.alphaValue < 0.05
            guard appearing else { return }
            var start = target
            start.origin.y -= 10
            todoWindow.ignoresMouseEvents = false
            todoWindow.setFrame(start, display: true)
            todoWindow.alphaValue = 0
            todoWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            todoWindow.makeKey()
            animateLyricsWindow {
                todoWindow.animator().alphaValue = 1
                todoWindow.animator().setFrame(target, display: true)
            }
            if !todo.userPlaced {
                todo.userPlaced = true
                todo.rememberOrigin(target.origin)
            }
        } else if todoWindow.isVisible {
            animateLyricsWindow({
                todoWindow.animator().alphaValue = 0
            }, completion: { [weak self] in
                guard let self, !self.todo.isOpen else { return }
                todoWindow.ignoresMouseEvents = true
                todoWindow.orderOut(nil)
            })
        }
    }

    private func applyTodoWindowFrame() {
        guard todoWindow?.isVisible == true, (todoWindow?.alphaValue ?? 0) > 0.05 else { return }
        guard let todoWindow, let target = todoFrame() else { return }
        todoWindow.setFrame(target, display: true, animate: false)
        todoWindow.contentView?.frame = NSRect(origin: .zero, size: target.size)
    }

    private func todoFrame() -> NSRect? {
        guard let screen = NotchGeometry.targetScreen else { return nil }
        let size = todo.panelSize
        if todo.isResizing {
            return NSRect(
                x: todo.pinnedLeft,
                y: todo.pinnedTop - size.height,
                width: size.width,
                height: size.height
            )
        }
        if todo.userPlaced, let origin = todo.panelOrigin {
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

    private func setupConfettiWindow() {
        let frame = NotchGeometry.targetScreen?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let host = NSHostingView(rootView: ConfettiOverlayView(todo: todo))
        host.frame = NSRect(origin: .zero, size: frame.size)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovable = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.contentView = host
        window.orderOut(nil)
        confettiWindow = window
    }

    private func showConfetti() {
        guard let screen = NotchGeometry.targetScreen, let confettiWindow else { return }
        let frame = screen.frame
        confettiWindow.setFrame(frame, display: true)
        confettiWindow.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        confettiWindow.alphaValue = 1
        confettiWindow.orderFrontRegardless()

        confettiHideWorkItem?.cancel()
        let hide = DispatchWorkItem { [weak self] in
            self?.confettiWindow?.orderOut(nil)
        }
        confettiHideWorkItem = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8, execute: hide)
    }

    private func setupScheduleSettingsWindow() {
        let hosting = NSHostingView(rootView: ScheduleSettingsView(schedule: scheduleManager))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Расписание Insula"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        scheduleSettingsWindow = window

        scheduleManager.$isSettingsOpen
            .receive(on: RunLoop.main)
            .sink { [weak self] open in
                guard let self, let window = self.scheduleSettingsWindow else { return }
                if open {
                    window.center()
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                } else {
                    window.orderOut(nil)
                }
            }
            .store(in: &guideCancellables)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleManager.isSettingsOpen = false
        }
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

private final class TodoWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let app = NSApp.delegate as? AppDelegate else { return }
        guard app.todo.userPlaced, !app.todo.isResizing else { return }
        app.todo.rememberOrigin(window.frame.origin)
        app.todo.persistPanel()
    }
}
