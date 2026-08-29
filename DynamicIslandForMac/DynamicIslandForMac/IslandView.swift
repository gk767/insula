import SwiftUI
import Combine

struct IslandView: View {
    @ObservedObject var state: IslandState
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var timerManager: IslandTimerManager
    @ObservedObject var scheduleManager: ScheduleManager
    @ObservedObject var clipboard: ClipboardHistory
    @ObservedObject var lyrics: LyricsManager
    @ObservedObject var playlist: PlaylistManager
    @ObservedObject var audioOutput: AudioOutputManager
    @ObservedObject var micMute: MicMuteManager
    @ObservedObject var guide: IslandGuide

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var pulseDown: CGFloat = 0
    @State private var ringProgress: [CGFloat] = [0, 0, 0, 0]
    @State private var rippleToken = 0
    @State private var rippleForward = true
    @State private var pauseToken = 0
    @State private var pauseProgress: [CGFloat] = [0, 0, 0, 0]
    @State private var previousOrigin: CGPoint?
    @State private var pauseOrigin: CGPoint?
    @State private var nextOrigin: CGPoint?
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var clipboardOpen = false
    @State private var scheduleOpen = false
    @State private var openedClipboardID: UUID?
    @State private var copiedClipboardID: UUID?

    private var expanded: Bool { state.isExpanded }
    private var showProgress: Bool { nowPlaying.duration > 1 }

    private var progressTickPaused: Bool {
        isScrubbing ? false : !expanded || !showProgress
    }

    private var progressTickInterval: TimeInterval {
        isScrubbing ? 1.0 / 24.0 : 1.0
    }

    private var collapsedProgressPaused: Bool {
        expanded || (!showProgress && !nowPlaying.isPlaying)
    }

    private var hasActivity: Bool {
        timerManager.isRunning
            || timerManager.didFinish
            || scheduleManager.nextItem?.isUrgent == true
            || nowPlaying.isPlaying
            || !nowPlaying.title.isEmpty
    }

    private var schedulePanelHeight: CGFloat {
        guard showsSchedulePanel else { return 0 }
        if !scheduleManager.isAuthorized { return 36 }
        let rows = max(scheduleManager.timelineItems.count, 1)
        return CGFloat(rows) * 20 + 8
    }

    private var timerSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private var notchInset: CGFloat {
        if NotchGeometry.hasPhysicalNotch {
            return max(state.collapsedSize.height + 12, 42)
        }
        return 16
    }

    private var isSideDock: Bool {
        if state.isRelocating, state.magnet == nil { return false }
        return NotchGeometry.isSide(state.dockedPlacement)
    }

    private var showsClipboardPanel: Bool {
        clipboardOpen && state.shows(.clipboard)
    }

    private var showsSchedulePanel: Bool {
        scheduleOpen && state.shows(.schedule) && state.earSlots.compactMap({ $0 }).contains(.schedule) && expanded
    }

    private var showsEarRow: Bool {
        true
    }

    private var showEditChrome: Bool {
        NotchGeometry.showsEditChrome(
            expanded: expanded,
            editing: state.isEditing,
            relocating: state.isRelocating
        )
    }

    private var expandedHeight: CGFloat {
        if isSideDock {
            var height = NotchGeometry.sideExpandedHeight(
                hasArtwork: nowPlaying.artwork != nil,
                showProgress: showProgress
            )
            if showsClipboardPanel {
                height += CGFloat(max(clipboard.items.count, 1)) * 22 + 8
                if let opened = clipboard.items.first(where: { $0.id == openedClipboardID }) {
                    let lines = min(8, max(2, (opened.text.count / 28) + opened.text.filter { $0.isNewline }.count + 1))
                    height += CGFloat(lines) * 14 + 28
                }
            }
            if showsSchedulePanel {
                height += schedulePanelHeight
            }
            return height
        }
        var content: CGFloat = {
            if state.useOwnerLayout {
                return showProgress ? 92 : 40
            }
            return showProgress ? 72 : 36
        }()
        if !state.useOwnerLayout, showsEarRow {
            content += 56
        }
        if showsClipboardPanel {
            content += CGFloat(max(clipboard.items.count, 1)) * 22 + 8
            if let opened = clipboard.items.first(where: { $0.id == openedClipboardID }) {
                let lines = min(8, max(2, (opened.text.count / 36) + opened.text.filter { $0.isNewline }.count + 1))
                content += CGFloat(lines) * 14 + 28
            }
        }
        if showsSchedulePanel {
            content += schedulePanelHeight
        }
        return content + (state.useOwnerLayout ? notchInset : 12)
    }

    private var collapsedVisualSize: CGSize {
        let place = state.isRelocating && state.magnet == nil ? IslandPlacement.bottom : state.dockedPlacement
        return NotchGeometry.collapsedVisualSize(notch: state.collapsedSize, activity: true, placement: place)
    }

    private var stackAlignment: Alignment {
        if state.isRelocating, state.magnet == nil { return .center }
        switch state.dockedPlacement {
        case .home: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var pulseAnchor: UnitPoint {
        if state.isRelocating, state.magnet == nil { return .center }
        switch state.dockedPlacement {
        case .home: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var islandWidth: CGFloat {
        if isSideDock {
            return expanded ? NotchGeometry.sideExpandedSize : NotchGeometry.sideCollapsedSize
        }
        return expanded ? NotchGeometry.expandedWidth : collapsedVisualSize.width
    }

    private var islandHeight: CGFloat {
        if isSideDock {
            return expanded ? expandedHeight : NotchGeometry.sideCollapsedSize
        }
        return expanded ? expandedHeight : collapsedVisualSize.height
    }

    private var islandRadius: CGFloat {
        if isSideDock {
            return expanded ? NotchGeometry.sideExpandedRadius : NotchGeometry.sideCollapsedRadius
        }
        return expanded ? 20.0 : islandHeight / 2
    }

    private var islandWithChrome: some View {
        let show = showEditChrome
        let gap = show ? NotchGeometry.editChromeGap : 0
        let placement = (state.isRelocating && state.magnet == nil) ? IslandPlacement.home : state.dockedPlacement
        return Group {
            switch placement {
            case .home:
                VStack(spacing: gap) {
                    islandCapsule
                    chromeSlot
                }
            case .bottom:
                VStack(spacing: gap) {
                    chromeSlot
                    islandCapsule
                }
            case .left:
                HStack(spacing: gap) {
                    islandCapsule
                    chromeSlot
                }
            case .right:
                HStack(spacing: gap) {
                    chromeSlot
                    islandCapsule
                }
            }
        }
    }

    private var chromeSlot: some View {
        editChrome
            .opacity(showEditChrome ? 1 : 0)
            .frame(
                width: showEditChrome ? nil : 0,
                height: showEditChrome ? nil : 0
            )
            .allowsHitTesting(showEditChrome)
    }

    private var islandCapsule: some View {
        let width = islandWidth
        let height = islandHeight
        let radius = islandRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let squishFactor = expanded ? 1.0 : (1 - state.approachSquish * 0.32)

        return ZStack(alignment: .top) {
            Color.clear
                .frame(width: width, height: height)
                .islandGlass(shape)

            expandedContent
                .frame(width: width, height: height, alignment: .top)
                .transaction { $0.animation = nil }
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
                .clipShape(shape)

            miniPlayerRow
                .padding(.horizontal, isSideDock ? 10 : 16)
                .padding(.vertical, isSideDock ? 8 : (state.useOwnerLayout ? 4 : 0))
                .frame(
                    width: width,
                    height: height,
                    alignment: .center
                )
                .compositingGroup()
                .opacity(expanded ? 0 : 1)
                .allowsHitTesting(!expanded)
                .clipShape(shape)
        }
        .frame(width: width, height: height, alignment: .top)
        .overlayPreferenceValue(RippleAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let resolved = RippleOrigins(
                    previous: anchors[.previous].map { CGPoint(x: proxy[$0].midX, y: proxy[$0].midY) },
                    pause: anchors[.pause].map { CGPoint(x: proxy[$0].midX, y: proxy[$0].midY) },
                    next: anchors[.next].map { CGPoint(x: proxy[$0].midX, y: proxy[$0].midY) }
                )
                Color.clear
                    .onAppear { applyRippleOrigins(resolved) }
                    .onChange(of: resolved) { _, value in
                        applyRippleOrigins(value)
                    }
            }
            .allowsHitTesting(false)
        }
        .overlay {
            skipRippleLayer(
                skipOrigin: rippleForward ? nextOrigin : previousOrigin,
                pauseOrigin: pauseOrigin
            )
            .clipShape(shape)
            .allowsHitTesting(false)
        }
        .scaleEffect(x: 1, y: squishFactor * (1 + 0.08 * pulseDown), anchor: pulseAnchor)
        .offset(x: state.shakeOffset)
        .guideTarget(.capsule)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: expanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: hasActivity)
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: expandedHeight)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSideDock)
        .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.86), value: state.approachSquish)
    }

    @ViewBuilder
    private var editChrome: some View {
        editTray
    }

    private var editButton: some View {
        let on = state.isEditing
        return Button {
            if on {
                state.endEditing()
        } else {
                state.beginEditing()
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(on ? 0.92 : 0.7))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Редакт Insula")
        .guideTarget(.edit)
    }

    private var guideButton: some View {
        let on = guide.isActive
        return Button {
            guide.toggle()
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(on ? 0.92 : 0.7))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Guide")
        .guideTarget(.guide)
    }

    private var editTray: some View {
        let side = isSideDock
        return Group {
            if side {
                VStack(spacing: 8) {
                    animationTrayButton
                    ForEach(state.hiddenModules) { module in
                        trayChip(module)
                    }
                    Spacer(minLength: 4)
                    editDoneButton
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            } else {
                HStack(spacing: 8) {
                    animationTrayButton
                    ForEach(state.hiddenModules) { module in
                        trayChip(module)
                    }
                    if state.hiddenModules.isEmpty {
                        Text("All on the island")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    editDoneButton
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .frame(
            width: side ? NotchGeometry.editSideTraySize.width : NotchGeometry.editTraySize.width,
            height: side ? NotchGeometry.editSideTraySize.height : NotchGeometry.editTraySize.height
        )
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.32))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
        }
        .environment(\.colorScheme, .dark)
        .guideTarget(.editTray)
    }

    private var animationTrayButton: some View {
        let on = state.transportAnimationsOn
        return Button {
            state.toggleTransportAnimations()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(on ? 0.62 : 0.28), lineWidth: 0.7)
                    .frame(width: 18, height: 18)
                Image(systemName: "sparkles")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white.opacity(on ? 0.88 : 0.32))
            }
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(on ? 0.12 : 0.06)))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(on ? "Анимация паузы и перемотки: вкл" : "Анимация паузы и перемотки: выкл")
    }

    private func trayChip(_ module: IslandModule) -> some View {
        Button {
            state.reveal(module)
        } label: {
            Image(systemName: module.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help(module.title)
    }

    private var editDoneButton: some View {
        Button {
            state.endEditing()
        } label: {
            Text("Done")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Done")
    }

    private var editMinus: some View {
        Image(systemName: "minus.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.black.opacity(0.55))
            .font(.system(size: 11, weight: .semibold))
            .offset(x: 5, y: -5)
            .allowsHitTesting(false)
    }

    private var timerMinus: some View {
        Image(systemName: "minus.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.black.opacity(0.55))
            .font(.system(size: 11, weight: .semibold))
            .offset(x: 3, y: 1)
            .allowsHitTesting(false)
    }

    var body: some View {
        ZStack(alignment: stackAlignment) {
            Color.clear

            islandWithChrome
        }
        .environment(\.islandGuide, guide)
        .onAppear {
            state.showsActivity = true
            state.expandedHeight = expandedHeight
            if state.shows(.schedule) {
                scheduleManager.refresh()
            }
        }
        .onChange(of: expandedHeight) { _, value in
            state.expandedHeight = value
        }
        .onChange(of: expanded) { _, isOn in
            if !isOn {
                clipboardOpen = false
                scheduleOpen = false
                openedClipboardID = nil
                copiedClipboardID = nil
            }
        }
        .onChange(of: state.modules) { _, _ in
            if !state.shows(.clipboard) {
                clipboardOpen = false
                openedClipboardID = nil
                copiedClipboardID = nil
            }
            if !state.shows(.lyrics) {
                lyrics.isOpen = false
            }
            if !state.shows(.playlist) {
                playlist.isOpen = false
            }
            if !state.shows(.guide) {
                guide.stop()
            }
            if !state.shows(.schedule) {
                scheduleOpen = false
            }
            state.expandedHeight = expandedHeight
        }
        .onChange(of: clipboardOpen) { _, isOn in
            if !isOn {
                openedClipboardID = nil
                copiedClipboardID = nil
            }
            state.expandedHeight = expandedHeight
        }
        .onChange(of: openedClipboardID) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: scheduleManager.nextItem?.id) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: scheduleManager.todayEvents.count) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: scheduleManager.todayReminders.count) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: scheduleOpen) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: state.earSlots) { _, _ in
            state.expandedHeight = expandedHeight
        }
        .onChange(of: state.pulseGeneration) { _, generation in
            guard generation > 0 else { return }
            playPulse()
        }
    }

    private func playPulse() {
        rippleToken += 1
        let token = rippleToken
        withAnimation(.easeInOut(duration: 0.28)) { pulseDown = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard token == rippleToken else { return }
            withAnimation(.easeInOut(duration: 0.34)) { pulseDown = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            guard token == rippleToken else { return }
            withAnimation(.easeInOut(duration: 0.28)) { pulseDown = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            guard token == rippleToken else { return }
            withAnimation(.easeInOut(duration: 0.4)) { pulseDown = 0 }
        }
    }

    private func playSkipRipple(forward: Bool) {
        guard state.transportAnimationsOn else { return }
        rippleToken += 1
        let token = rippleToken
        rippleForward = forward
        ringProgress = Array(repeating: 0, count: ringProgress.count)
        pulseDown = 0

        let gap = 0.22
        for index in ringProgress.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * gap) {
                guard token == rippleToken else { return }
                beatPulse(token: token)
                withAnimation(.easeOut(duration: 0.72)) {
                    var next = ringProgress
                    next[index] = 1
                    ringProgress = next
                }
            }
        }
    }

    private func beatPulse(token: Int) {
        withAnimation(.easeInOut(duration: 0.26)) { pulseDown = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            guard token == rippleToken else { return }
            withAnimation(.easeInOut(duration: 0.3)) { pulseDown = 0 }
        }
    }

    private func playPauseRipple() {
        guard state.transportAnimationsOn else { return }
        pauseToken += 1
        let token = pauseToken
        pauseProgress = Array(repeating: 0, count: pauseProgress.count)

        let gap = 0.22
        for index in pauseProgress.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * gap) {
                guard token == pauseToken else { return }
                beatPulse(token: rippleToken)
                withAnimation(.easeOut(duration: 0.72)) {
                    var next = pauseProgress
                    next[index] = 1
                    pauseProgress = next
                }
            }
        }
    }

    private func applyRippleOrigins(_ origins: RippleOrigins) {
        if previousOrigin != origins.previous { previousOrigin = origins.previous }
        if pauseOrigin != origins.pause { pauseOrigin = origins.pause }
        if nextOrigin != origins.next { nextOrigin = origins.next }
    }

    private func skipRippleLayer(skipOrigin: CGPoint?, pauseOrigin: CGPoint?) -> some View {
        ZStack {
            if let skipOrigin {
                ForEach(ringProgress.indices, id: \.self) { index in
                    let progress = ringProgress[index]
                    Circle()
                        .stroke(
                            Color.white.opacity(0.72 * (1 - progress)),
                            lineWidth: 2.2
                        )
                        .frame(width: 28, height: 28)
                        .scaleEffect(0.35 + progress * 5.2)
                        .opacity(progress == 0 ? 0 : 1)
                        .position(skipOrigin)
                }
            }

            if let pauseOrigin {
                ForEach(pauseProgress.indices, id: \.self) { index in
                    let progress = pauseProgress[index]
                    Circle()
                        .stroke(
                            Color.white.opacity(0.58 * (1 - progress)),
                            lineWidth: 2.2
                        )
                        .frame(width: 28, height: 28)
                        .scaleEffect(4.72 * (1 - progress / 3))
                        .opacity(progress == 0 ? 0 : 1)
                        .position(pauseOrigin)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var miniPlayerRow: some View {
        Group {
            if isSideDock {
                sideMiniPlayer
            } else {
                horizontalMiniPlayer
            }
        }
        .foregroundStyle(.white)
    }

    private var horizontalMiniPlayer: some View {
        HStack(spacing: 7) {
            TimelineView(.animation(
                minimumInterval: 1.0,
                paused: collapsedProgressPaused
            )) { context in
                let elapsed = nowPlaying.elapsed(at: context.date)
        HStack(spacing: 6) {
                    if showProgress {
                        TrackProgressRing(
                            progress: progressValue(elapsed: elapsed),
                            size: 12,
                            line: 1.5
                        )
                        .padding(1)
                        .fixedSize()
                    } else if nowPlaying.isPlaying {
                        PlayingBars(barCount: 4, maxHeight: 10, paused: expanded)
                    }
                    Text(nowPlaying.title.isEmpty ? "Ничего не играет" : collapsedTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if showProgress {
                        Text(formatTime(elapsed))
                            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(-1)
                    }
                }
                .guideTarget(.collapsedMusic)
            }

            Spacer(minLength: 4)

            if state.shows(.timer) {
                HStack(spacing: 4) {
                Image(systemName: "timer")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(timerManager.isRunning || timerManager.didFinish ? 0.92 : 0.45))
                    Text(collapsedTimerText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white.opacity(timerManager.didFinish ? 0.92 : 0.78))
                }
                .guideTarget(.collapsedTimer)
            }

            if state.shows(.schedule), scheduleManager.nextItem != nil, !expanded {
                TimelineView(.periodic(from: .now, by: scheduleManager.nextItem?.isUrgent == true ? 10 : 60)) { _ in
                    HStack(spacing: 3) {
                        TrackProgressRing(
                            progress: scheduleManager.countdownProgress(for: scheduleManager.nextItem),
                            size: 11,
                            line: 1.4
                        )
                        if let short = scheduleManager.collapsedShortText() {
                            Text(short)
                                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(.white.opacity(scheduleManager.nextItem?.isUrgent == true ? 0.95 : 0.62))
                        }
                    }
                    .guideTarget(.collapsedSchedule)
                }
            }
        }
    }

    private var sideMiniPlayer: some View {
        VStack(spacing: 5) {
            ZStack {
                if let artwork = nowPlaying.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else if nowPlaying.isPlaying {
                    PlayingBars(barCount: 4, maxHeight: 16, paused: expanded)
                } else {
                Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                }
                if showProgress {
                    TimelineView(.animation(minimumInterval: 1.0, paused: expanded)) { context in
                        TrackProgressRing(
                            progress: progressValue(elapsed: nowPlaying.elapsed(at: context.date)),
                            size: 40,
                            line: 1.7
                        )
                    }
                }
            }
            .frame(width: 40, height: 40)

            Text(nowPlaying.title.isEmpty ? "Тишина" : nowPlaying.title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

            if state.shows(.timer) {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(timerManager.isRunning || timerManager.didFinish ? 0.92 : 0.45))
                    Text(collapsedTimerText)
                        .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white.opacity(timerManager.didFinish ? 0.92 : 0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .guideTarget(.collapsedTimer)
            }

            if state.shows(.schedule), scheduleManager.nextItem != nil, !expanded {
                TimelineView(.periodic(from: .now, by: scheduleManager.nextItem?.isUrgent == true ? 10 : 60)) { _ in
                    HStack(spacing: 2) {
                        TrackProgressRing(
                            progress: scheduleManager.countdownProgress(for: scheduleManager.nextItem),
                            size: 10,
                            line: 1.3
                        )
                        if let short = scheduleManager.collapsedShortText() {
                            Text(short)
                                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(.white.opacity(scheduleManager.nextItem?.isUrgent == true ? 0.95 : 0.62))
                        }
                    }
                    .guideTarget(.collapsedSchedule)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .guideTarget(.collapsedMusic)
    }

    private var collapsedTimerText: String {
        if timerManager.didFinish { return "Готово" }
        if timerManager.isRunning { return timerManager.formatted }
        return formatCountdown(timerSeconds)
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var expandedContent: some View {
        Group {
            if isSideDock {
                sideExpandedContent
            } else if state.useOwnerLayout {
                ownerExpandedContent
            } else {
                guestExpandedContent
            }
        }
        .allowsHitTesting(expanded)
    }

    private var sideExpandedContent: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                timerSlot
                    .scaleEffect(0.84, anchor: .leading)
                Spacer(minLength: 4)
                rightEarControls
            }
            .frame(minHeight: 36)

            if let artwork = nowPlaying.artwork {
                Button { nowPlaying.openPlayer() } label: {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .id("\(nowPlaying.title)|\(nowPlaying.artist)")
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    if nowPlaying.artwork == nil, nowPlaying.isPlaying, !nowPlaying.title.isEmpty {
                        PlayingBars(barCount: 4, maxHeight: 11, paused: !expanded)
                    }
                    Text(nowPlaying.title.isEmpty ? "Ничего не играет" : nowPlaying.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if !nowPlaying.artist.isEmpty {
                    Text(nowPlaying.artist)
                    .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .guideTarget(.media)

            transportButtons

            if showsClipboardPanel {
                clipboardList
            }
            if showsSchedulePanel {
                scheduleList
            }
            if showProgress {
                progressSection
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
    }

    private var ownerExpandedContent: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .center, spacing: 0) {
                timerSlot
                Spacer(minLength: 0)
                rightEarControls
            }
            .padding(.horizontal, 10)
            .frame(height: max(state.collapsedSize.height, 32))

            VStack(alignment: .leading, spacing: 6) {
            mediaSection
                if showsClipboardPanel {
                    clipboardList
                }
                if showsSchedulePanel {
                    scheduleList
                }
                if showProgress {
            progressSection
                }
            }
            .padding(.top, notchInset)
            .padding(.horizontal, 12)
            .padding(.bottom, showProgress ? 16 : 14)
        }
    }

    private var guestExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsEarRow {
                HStack(alignment: .center, spacing: 8) {
                    timerSlot
                    Spacer(minLength: 8)
                    rightEarControls
                }
            }
            mediaSection
            if showsClipboardPanel {
                clipboardList
            }
            if showsSchedulePanel {
                scheduleList
            }
            if showProgress {
                progressSection
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }


    private var mediaSection: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if let artwork = nowPlaying.artwork {
                    Button { nowPlaying.openPlayer() } label: {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .id("\(nowPlaying.title)|\(nowPlaying.artist)")
                    }
                    .buttonStyle(.plain)
                }

            VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if nowPlaying.artwork == nil, nowPlaying.isPlaying, !nowPlaying.title.isEmpty, !showProgress {
                            PlayingBars(barCount: 4, maxHeight: 11, paused: !expanded)
                        }
                Text(nowPlaying.title.isEmpty ? "Ничего не играет" : nowPlaying.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if !nowPlaying.artist.isEmpty {
                Text(nowPlaying.artist)
                    .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.48))
                    .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .guideTarget(.media)

            Spacer(minLength: 8)

            transportButtons
        }
        .buttonStyle(.plain)
        .foregroundColor(.white.opacity(0.88))
        .font(.system(size: 12))
    }

    private var transportButtons: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    nowPlaying.send(.previousTrack)
                    playSkipRipple(forward: false)
                } label: {
                    Image(systemName: "backward.fill")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .rippleTarget(.previous)

                Button {
                    if nowPlaying.isPlaying {
                        playPauseRipple()
                    }
                    nowPlaying.send(.togglePlayPause)
                } label: {
                    Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .rippleTarget(.pause)

                Button {
                    nowPlaying.send(.nextTrack)
                    playSkipRipple(forward: true)
                } label: {
                    Image(systemName: "forward.fill")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                }
                .rippleTarget(.next)
            }
            .guideTarget(.transport)

            audioOutputSlot

            if state.shows(.lyrics) {
                Button {
                    if state.isEditing {
                        state.hide(.lyrics)
                    } else {
                        lyrics.toggle()
                    }
                } label: {
                    Image(systemName: "quote.bubble")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .foregroundColor(.white.opacity(state.isEditing || lyrics.available ? 0.88 : 0.22))
                        .overlay(alignment: .topTrailing) {
                            if state.isEditing { editMinus }
                }
            }
            .buttonStyle(.plain)
                .disabled(!state.isEditing && !lyrics.available)
                .help(state.isEditing ? "Убрать с островка" : (lyrics.available ? "Текст песни" : "Текст недоступен"))
                .guideTarget(.lyrics)
            }

            if state.shows(.playlist), playlist.available || state.isEditing {
                Button {
                    if state.isEditing {
                        state.hide(.playlist)
                    } else {
                        playlist.toggle()
                    }
                } label: {
                    Image(systemName: "music.note.list")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .overlay(alignment: .topTrailing) {
                            if state.isEditing { editMinus }
                        }
                }
                .buttonStyle(.plain)
                .help(state.isEditing ? "Убрать с островка" : "Актуальный плейлист")
                .guideTarget(.playlist)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.white.opacity(0.88))
        .font(.system(size: 12))
    }

    private var rightEarControls: some View {
        HStack(alignment: .center, spacing: 2) {
            editButton
            ForEach(0..<3, id: \.self) { index in
                utilityEarSlot(index)
            }
        }
    }

    private func utilityEarSlot(_ index: Int) -> some View {
        Group {
            if let module = state.module(atEarSlot: index) {
                utilityEarModuleView(module, slot: index)
            } else if state.isEditing {
                Button {
                    state.cycleEarSlot(at: index)
                } label: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                }
                .buttonStyle(.plain)
                .help("Назначить кнопку")
            }
        }
    }

    @ViewBuilder
    private func utilityEarModuleView(_ module: IslandModule, slot index: Int) -> some View {
        Group {
            switch module {
            case .guide:
                guideButton
            case .clipboard:
                clipboardButton
            case .micMute:
                micMuteButton
            case .schedule:
                scheduleUtilityButton
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(!state.isEditing)
        .overlay(alignment: .topTrailing) {
            if state.isEditing {
                utilitySlotEditOverlay(module, slot: index)
            }
        }
        .overlay {
            if state.isEditing {
                Button {
                    state.cycleEarSlot(at: index)
                } label: {
                    Color.clear
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Сменить кнопку")
            }
        }
    }

    private func utilitySlotEditOverlay(_ module: IslandModule, slot index: Int) -> some View {
        Button {
            state.hide(module)
        } label: {
            Image(systemName: "minus.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.55))
                .font(.system(size: 11, weight: .semibold))
                .offset(x: 5, y: -5)
        }
        .buttonStyle(.plain)
        .help("Убрать с островка")
    }

    private var scheduleUtilityButton: some View {
        Button {
            if !scheduleManager.isAuthorized {
                scheduleManager.requestAccess()
            } else {
                scheduleOpen.toggle()
                if scheduleOpen { clipboardOpen = false }
            }
        } label: {
            scheduleUtilityIcon
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Календари и напоминания…") {
                scheduleManager.toggleSettings()
            }
        }
        .help(scheduleManager.isAuthorized ? "Расписание" : "Разрешить календарь")
        .guideTarget(.schedule)
    }

    private var scheduleUtilityIcon: some View {
        TimelineView(.periodic(from: .now, by: scheduleManager.nextItem?.isUrgent == true ? 10 : 60)) { _ in
            ZStack {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(scheduleOpen ? 0.95 : 0.72))
                    .frame(width: 26, height: 26)
                if scheduleManager.isAuthorized, let next = scheduleManager.nextItem, !next.isAllDay {
                    TrackProgressRing(
                        progress: scheduleManager.countdownProgress(for: next),
                        size: 24,
                        line: 1.6
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private var micMuteButton: some View {
        Button {
            micMute.toggle()
        } label: {
            if micMute.isMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white))
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(width: 26, height: 26)
            }
        }
        .buttonStyle(.plain)
        .help(micMute.isMuted ? "Микрофон выключен" : "Микрофон")
        .guideTarget(.mic)
    }

    private var audioOutputSlot: some View {
        Group {
            if state.shows(.audioOutput) {
                HStack(spacing: 4) {
                    if audioOutput.speakersAvailable {
                        outputCircle(
                            route: .speakers,
                            symbol: "hifi.speaker.fill",
                            help: "Колонки"
                        )
                    }
                    if audioOutput.headphonesAvailable {
                        outputCircle(
                            route: .headphones,
                            symbol: "headphones",
                            help: "Наушники"
                        )
                    }
                    outputCircle(
                        route: .mac,
                        symbol: "macbook",
                        help: "MacBook"
                    )
                    if audioOutput.carAvailable {
                        outputCircle(
                            route: .car,
                            symbol: "car.fill",
                            help: "Машина"
                        )
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
                .overlay(alignment: .topTrailing) {
                    if state.isEditing { editMinus }
                }
                .guideTarget(.audio)
            }
        }
    }

    private func outputCircle(route: AudioOutputRoute, symbol: String, help: String) -> some View {
        let on = audioOutput.route == route
        return Button {
            if state.isEditing {
                state.hide(.audioOutput)
            } else {
                audioOutput.select(route)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(on ? .black : .white.opacity(0.42))
                .frame(width: 20, height: 20)
                .background(Circle().fill(on ? Color.white : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help(state.isEditing ? "Убрать с островка" : help)
    }

    private var timerSlot: some View {
        Group {
            if state.shows(.timer) {
                timerSection
                    .allowsHitTesting(!state.isEditing)
                    .overlay {
                        if state.isEditing {
                            Button {
                                state.hide(.timer)
                            } label: {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .help(state.isEditing ? "Убрать с островка" : "Таймер")
                    .guideTarget(.timer)
            }
        }
    }

    private var clipboardButton: some View {
        Button {
            clipboardOpen.toggle()
            if clipboardOpen { scheduleOpen = false }
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(clipboardOpen ? 0.92 : 0.7))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Буфер обмена")
        .guideTarget(.clipboard)
    }

    private var clipboardList: some View {
        VStack(alignment: .leading, spacing: 3) {
            if clipboard.items.isEmpty {
                Text("Пусто")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            } else {
                ForEach(clipboard.items) { item in
                    clipboardRow(item)
                }
            }
        }
    }

    private func clipboardRow(_ item: ClipboardHistory.Item) -> some View {
        let opened = openedClipboardID == item.id
        return VStack(alignment: .leading, spacing: 5) {
            Button {
                openedClipboardID = opened ? nil : item.id
                copiedClipboardID = nil
            } label: {
                HStack(spacing: 6) {
                    Text(ClipboardHistory.preview(item.text))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: opened ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(opened ? 0.1 : 0.06)))
            }
            .buttonStyle(.plain)

            if opened {
                Text(item.text)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(8)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)

                Button {
                    clipboard.copyAgain(item.text)
                    copiedClipboardID = item.id
                } label: {
                    Text(copiedClipboardID == item.id ? "Скопировано" : "Скопировать")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(copiedClipboardID == item.id ? .black : .white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(copiedClipboardID == item.id ? Color.white : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            }
        }
    }

    private func progressValue(elapsed: Double) -> Double {
        guard nowPlaying.duration > 0 else { return 0 }
        return min(1, max(0, elapsed / nowPlaying.duration))
    }

    private var progressSection: some View {
        TimelineView(.animation(minimumInterval: progressTickInterval, paused: progressTickPaused)) { context in
            let elapsed = isScrubbing ? scrubValue : nowPlaying.elapsed(at: context.date)
            let progress = progressValue(elapsed: elapsed)

            HStack(alignment: .center, spacing: 8) {
                TrackProgressRing(progress: progress, size: 13, line: 1.5)
                    .fixedSize()
                    .layoutPriority(1)

                VStack(alignment: .leading, spacing: 3) {
                    TrackTimeline(progress: progress, isDragging: isScrubbing) { fraction in
                        let value = fraction * nowPlaying.duration
                        isScrubbing = true
                        scrubValue = value
                        nowPlaying.beginScrub(to: value)
                    } onEnd: { fraction in
                        let value = fraction * nowPlaying.duration
                        scrubValue = value
                        nowPlaying.seek(to: value)
                        isScrubbing = false
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 4) {
                        Text(formatTime(elapsed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatTime(nowPlaying.duration))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(playbackTimeFont)
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transaction { $0.animation = nil }
        .guideTarget(.progress)
    }

    private var playbackTimeFont: Font {
        let longest = max(nowPlaying.duration, 0)
        if longest >= 3600 {
            return .system(size: 8, weight: .medium, design: .rounded).monospacedDigit()
        }
        return .system(size: 9, weight: .medium, design: .rounded).monospacedDigit()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private var timerSection: some View {
        Group {
            if timerManager.isRunning {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                Text(timerManager.formatted)
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    Button { timerManager.cancel() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(alignment: .topTrailing) {
                    if state.isEditing { timerMinus }
                }
            } else {
                HStack(spacing: 4) {
                    DurationWheel(value: $hours, range: 0...23, unit: "ч")
                    DurationWheel(value: $minutes, range: 0...59, unit: "мин")
                    DurationWheel(value: $seconds, range: 0...59, unit: "сек")
                    Button {
                        timerManager.start(seconds: timerSeconds)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(timerSeconds > 0 ? .black : .white.opacity(0.28))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(timerSeconds > 0 ? Color.white : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                    .disabled(timerSeconds <= 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(alignment: .topTrailing) {
                    if state.isEditing { timerMinus }
                }
                .scaleEffect(state.useOwnerLayout ? 0.72 : 1, anchor: .leading)
            }
        }
    }

    private var scheduleList: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !scheduleManager.isAuthorized {
                Button { scheduleManager.requestAccess() } label: {
                    Text("Разрешить Календарь и Напоминания")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
            } else if scheduleManager.timelineItems.isEmpty {
                Text("Сегодня свободно")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 6)
            } else {
                ForEach(scheduleManager.timelineItems) { item in
                    Button { scheduleManager.openApp(for: item.kind) } label: {
                        HStack(spacing: 6) {
                            Text(scheduleTimeLabel(for: item))
                                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(.white.opacity(item.isOverdue ? 0.35 : 0.48))
                                .frame(width: 34, alignment: .leading)
                            if let color = item.calendarColor {
                                Circle()
                                    .fill(color)
                                    .frame(width: 4, height: 4)
                            }
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(item.isOverdue ? 0.42 : 0.86))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: item.kind == .event ? "video" : "checkmark.circle")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.28))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .guideTarget(.schedule)
    }

    private func scheduleTimeLabel(for item: ScheduleItem) -> String {
        if item.isAllDay { return "день" }
        if item.isOverdue { return "!" }
        if let minutes = item.minutesUntil, minutes >= 0, minutes <= 59 {
            return "\(minutes)м"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: item.date)
    }

    private var collapsedTitle: String {
        let title = nowPlaying.title
        guard title.count > 20 else { return title }
        return String(title.prefix(19)) + "…"
    }
}

private enum RippleID: Hashable {
    case previous, pause, next
}

private struct RippleOrigins: Equatable {
    var previous: CGPoint?
    var pause: CGPoint?
    var next: CGPoint?
}

private struct RippleAnchorKey: PreferenceKey {
    static var defaultValue: [RippleID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [RippleID: Anchor<CGRect>], nextValue: () -> [RippleID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private extension View {
    func rippleTarget(_ id: RippleID) -> some View {
        anchorPreference(key: RippleAnchorKey.self, value: .bounds) { [id: $0] }
    }

    @ViewBuilder
    func islandGlass<S: Shape>(_ shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
                .overlay { islandTint(shape) }
                .overlay { islandRim(shape) }
                .environment(\.colorScheme, .dark)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.thinMaterial)
                        islandTint(shape)
                    }
                }
                .environment(\.colorScheme, .dark)
                .overlay { islandRim(shape) }
        }
    }

    func islandTint<S: Shape>(_ shape: S) -> some View {
        ZStack {
            shape.fill(Color.black.opacity(0.36))
            shape.fill(Color.white.opacity(0.08))
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.04),
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .allowsHitTesting(false)
    }

    func islandRim<S: Shape>(_ shape: S) -> some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.34),
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            lineWidth: 0.9
        )
        .allowsHitTesting(false)
    }
}

private struct DurationWheel: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    private let row: CGFloat = 15

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(height: row)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { number in
                        HStack(spacing: 1) {
                            Text(String(format: "%02d", number))
                                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                            Text(unit)
                                .font(.system(size: 6, weight: .medium))
                                .opacity(number == value ? 0.45 : 0.18)
                        }
                        .foregroundColor(.white.opacity(number == value ? 0.95 : 0.22))
                        .frame(width: 32, height: row)
                        .contentShape(Rectangle())
                        .onTapGesture { value = number }
                        .id(itemID(number))
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, row, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: scrollID, anchor: .center)
            .frame(height: row * 3)
            .mask(fadeMask)
        }
        .frame(width: 34, height: row * 3)
    }

    private func itemID(_ number: Int) -> String {
        "v-\(number)"
    }

    private var scrollID: Binding<String?> {
        Binding(
            get: { itemID(value) },
            set: { newValue in
                guard let newValue, let parsed = Int(newValue.dropFirst(2)), range.contains(parsed) else { return }
                value = parsed
            }
        )
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.3),
                .init(color: .black, location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TrackProgressRing: View {
    var progress: Double
    var size: CGFloat = 14
    var line: CGFloat = 1.6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.012, progress))
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .fixedSize()
    }
}

private struct TrackTimeline: View {
    var progress: Double
    var isDragging: Bool
    var onScrub: (Double) -> Void
    var onEnd: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let knob: CGFloat = isDragging ? 8 : 6
            let bar: CGFloat = isDragging ? 4 : 3
            let filled = width * min(1, max(0, progress))
            let knobX = max(0, min(width - knob, filled - knob / 2))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: width, height: bar)
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: max(bar, filled), height: bar)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .offset(x: knobX)
            }
            .frame(width: width, height: max(bar, knob), alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onScrub(min(1, max(0, value.location.x / width)))
                    }
                    .onEnded { value in
                        onEnd(min(1, max(0, value.location.x / width)))
                    }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
        .transaction { $0.animation = nil }
    }
}

private struct PlayingBars: View {
    var barCount: Int = 4
    var maxHeight: CGFloat = 11
    var paused: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 1.8) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 2.2, height: barHeight(index: index, t: t))
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func barHeight(index: Int, t: TimeInterval) -> CGFloat {
        let phase = Double(index) * 0.85
        let speed = 2.6 + Double(index) * 0.35
        let wave = (sin(t * speed + phase) + 1) / 2
        return 3 + (maxHeight - 3) * wave
    }
}
