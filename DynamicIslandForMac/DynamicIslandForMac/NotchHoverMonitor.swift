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

    private let expandDelay: TimeInterval = 0.1
    private let collapseDelay: TimeInterval = 0.16
    private let fastApproach: CGFloat = 640

    func start(state: IslandState) {
        self.state = state
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.012
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    deinit {
        timer?.invalidate()
        expandWork?.cancel()
        collapseWork?.cancel()
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
            state.mosesCursor = nil
            if state.isHovering {
                state.isHovering = false
                onHoveringChange?(false)
            }
            return
        }
        if state.guideHold == .collapsed || state.guideHold == .moses {
            if state.isHovering {
                state.isHovering = false
                onHoveringChange?(false)
            }
            if state.guideHold == .moses, state.placement == .home {
                let size = NotchGeometry.collapsedVisualSize(
                    notch: state.collapsedSize,
                    activity: state.showsActivity,
                    placement: state.placement
                )
                let demo = CGPoint(x: size.width / 2, y: size.height - 7)
                if state.mosesCursor != demo {
                    state.mosesCursor = demo
                }
            } else if state.mosesCursor != nil {
                state.mosesCursor = nil
            }
            return
        }
        if state.guideHold == .expanded || state.guideHold == .editing {
            state.mosesCursor = nil
            cancelCollapse()
            if !state.isHovering {
                state.isHovering = true
                onHoveringChange?(true)
            }
            return
        }
        if state.isEditing {
            state.mosesCursor = nil
            cancelCollapse()
            if !state.isHovering {
                state.isHovering = true
                onHoveringChange?(true)
            }
            return
        }
        guard let screen = NotchGeometry.targetScreen else { return }
        let point = NSEvent.mouseLocation
        if point == lastPoint { return }
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
        let inMoses = state.mosesCursor != nil
        if !inMoses, speed >= fastApproach {
            fastUntil = now + 0.12
        }

        if state.isHovering {
            state.mosesCursor = nil
            let inside = isInsideNotch(state, expanded: true) || (extraStayInside?() ?? false)
            if inside {
                cancelCollapse()
            } else {
                cancelExpand()
                scheduleCollapse()
            }
            return
        }

        let arrivingFast = !inMoses && now < fastUntil
        if arrivingFast, NotchGeometry.isOnCollapsedPill(point, activity: activity, on: screen, placement: placement, along: along) {
            cancelCollapse()
            scheduleExpand(requireDeep: false)
            return
        }

        if arrivingFast {
            cancelExpand()
            return
        }

        if placement != .home {
            state.mosesCursor = nil
            if NotchGeometry.isOnCollapsedPill(point, activity: activity, on: screen, placement: placement, along: along) {
                cancelCollapse()
                scheduleExpand(requireDeep: false)
            } else {
                cancelExpand()
            }
            return
        }

        let nextCursor = NotchGeometry.mosesCursorInPill(point, activity: activity, on: screen, placement: placement, along: along)
        if state.mosesCursor != nextCursor {
            state.mosesCursor = nextCursor
        }

        let deep = NotchGeometry.isDeepExpandZone(point, activity: activity, on: screen, placement: placement, along: along)
        if deep {
            cancelCollapse()
            scheduleExpand(requireDeep: true)
        } else {
            cancelExpand()
        }
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
            state.mosesCursor = nil
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
