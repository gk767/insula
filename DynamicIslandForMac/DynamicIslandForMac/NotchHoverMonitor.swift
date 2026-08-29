import Cocoa

final class NotchHoverMonitor {

    var onHoveringChange: ((Bool) -> Void)?
    var extraStayInside: (() -> Bool)?

    private weak var state: IslandState?
    private var timer: Timer?
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?

    private var lastPoint: NSPoint?
    private var lastTick: TimeInterval = 0
    private var fastUntil: TimeInterval = 0
    private var pollFast = false

    private let expandDelay: TimeInterval = 0.1
    private let collapseDelay: TimeInterval = 0.16
    private let fastApproach: CGFloat = 640

    func start(state: IslandState) {
        self.state = state
        installTimer(fast: false)
        tick()
    }

    deinit {
        timer?.invalidate()
        expandWork?.cancel()
        collapseWork?.cancel()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        expandWork?.cancel()
        collapseWork?.cancel()
        expandWork = nil
        collapseWork = nil
    }

    private func installTimer(fast: Bool) {
        pollFast = fast
        timer?.invalidate()
        let interval = fast ? 1.0 / 30.0 : 0.1
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = fast ? 0.008 : 0.04
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func setPollFast(_ fast: Bool) {
        guard fast != pollFast else { return }
        installTimer(fast: fast)
    }

    private func isInsideNotch(_ state: IslandState, expanded: Bool) -> Bool {
        guard let screen = NotchGeometry.targetScreen else { return false }
        return NotchGeometry.containsCursor(
            NSEvent.mouseLocation,
            expanded: expanded,
            activity: state.showsActivity,
            expandedHeight: state.expandedHeight,
            on: screen,
            placement: state.placement,
            along: state.along,
            collapsed: state.collapsedSize
        )
    }

    private func tick() {
        guard let state else { return }

        if state.isRelocating {
            state.approachSquish = 0
            if state.isHovering {
                state.isHovering = false
                onHoveringChange?(false)
            }
            updatePollRate(for: state)
            return
        }
        if state.guideHold == .collapsed || state.guideHold == .moses {
            if state.isHovering {
                state.isHovering = false
                onHoveringChange?(false)
            }
            if state.guideHold == .moses, state.placement == .home {
                let demo: CGFloat = 0.72
                if state.approachSquish != demo {
                    state.approachSquish = demo
                }
            } else if state.approachSquish != 0 {
                state.approachSquish = 0
            }
            updatePollRate(for: state)
            return
        }
        if state.guideHold == .expanded || state.guideHold == .editing {
            state.approachSquish = 0
            cancelCollapse()
            if !state.isHovering {
                state.isHovering = true
                onHoveringChange?(true)
            }
            updatePollRate(for: state)
            return
        }
        if state.isEditing {
            state.approachSquish = 0
            cancelCollapse()
            if !state.isHovering {
                state.isHovering = true
                onHoveringChange?(true)
            }
            updatePollRate(for: state)
            return
        }
        guard let screen = NotchGeometry.targetScreen else { return }
        let point = NSEvent.mouseLocation
        if point == lastPoint {
            updatePollRate(for: state, point: point, screen: screen)
            return
        }
        let activity = state.showsActivity
        let placement = state.placement
        let along = state.along
        let now = ProcessInfo.processInfo.systemUptime
        var speed: CGFloat = 0
        if let lastPoint, lastTick > 0 {
            let dt = max(now - lastTick, 1.0 / 120.0)
            speed = hypot(point.x - lastPoint.x, point.y - lastPoint.y) / CGFloat(dt)
        }
        lastPoint = point
        lastTick = now
        let inApproach = state.approachSquish > 0.02
        if !inApproach, speed >= fastApproach {
            fastUntil = now + 0.12
        }

        if state.isHovering {
            state.approachSquish = 0
            let inside = isInsideNotch(state, expanded: true) || (extraStayInside?() ?? false)
            if inside {
                cancelCollapse()
            } else {
                cancelExpand()
                scheduleCollapse()
            }
            updatePollRate(for: state, point: point, screen: screen)
            return
        }

        let arrivingFast = !inApproach && now < fastUntil
        if arrivingFast, NotchGeometry.isOnCollapsedPill(point, activity: activity, on: screen, placement: placement, along: along) {
            cancelCollapse()
            scheduleExpand(requireDeep: false)
            updatePollRate(for: state, point: point, screen: screen)
            return
        }

        if arrivingFast {
            cancelExpand()
            updatePollRate(for: state, point: point, screen: screen)
            return
        }

        if placement != .home {
            state.approachSquish = 0
            if NotchGeometry.isOnCollapsedPill(point, activity: activity, on: screen, placement: placement, along: along) {
                cancelCollapse()
                scheduleExpand(requireDeep: false)
            } else {
                cancelExpand()
            }
            updatePollRate(for: state, point: point, screen: screen)
            return
        }

        let nextSquish = NotchGeometry.approachSquish(point, activity: activity, on: screen, placement: placement, along: along)
        if state.approachSquish != nextSquish {
            state.approachSquish = nextSquish
        }

        let deep = NotchGeometry.isDeepExpandZone(point, activity: activity, on: screen, placement: placement, along: along)
        if deep {
            cancelCollapse()
            scheduleExpand(requireDeep: true)
        } else {
            cancelExpand()
        }
        updatePollRate(for: state, point: point, screen: screen)
    }

    private func updatePollRate(for state: IslandState, point: NSPoint? = nil, screen: NSScreen? = nil) {
        let mouse = point ?? NSEvent.mouseLocation
        let screen = screen ?? NotchGeometry.targetScreen
        let needsFast = state.approachSquish > 0.02
            || (screen.map {
                NotchGeometry.isInApproachZone(
                    mouse,
                    activity: state.showsActivity,
                    on: $0,
                    placement: state.placement,
                    along: state.along
                )
            } ?? false)
        setPollFast(needsFast)
    }

    private func scheduleExpand(requireDeep: Bool) {
        guard expandWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, let state = self.state else { return }
            self.expandWork = nil
            guard !state.isRelocating else { return }
            guard
                let screen = NotchGeometry.targetScreen
            else { return }
            let mouse = NSEvent.mouseLocation
            if state.placement == .home, requireDeep {
                guard NotchGeometry.isDeepExpandZone(
                    mouse,
                    activity: state.showsActivity,
                    on: screen,
                    placement: state.placement,
                    along: state.along
                ) else { return }
            } else {
                guard NotchGeometry.isOnCollapsedPill(
                    mouse,
                    activity: state.showsActivity,
                    on: screen,
                    placement: state.placement,
                    along: state.along
                ) else { return }
            }
            state.isHovering = true
            state.approachSquish = 0
            self.onHoveringChange?(true)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + expandDelay, execute: work)
    }

    private func scheduleCollapse() {
        guard collapseWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, let state = self.state else { return }
            self.collapseWork = nil
            if state.isEditing { return }
            if self.isInsideNotch(state, expanded: true) { return }
            state.isHovering = false
            self.onHoveringChange?(false)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: work)
    }

    private func cancelExpand() {
        expandWork?.cancel()
        expandWork = nil
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }
}
