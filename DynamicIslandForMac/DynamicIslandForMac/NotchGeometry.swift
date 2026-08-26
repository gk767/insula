import Cocoa
import Darwin

enum NotchGeometry {

    static let defaultCollapsedSize = CGSize(width: 155, height: 32)
    static let expandedSize = CGSize(width: 420, height: 360)
    static let floatingCollapsedSize = CGSize(width: 176, height: 36)
    static let floatingTopGap: CGFloat = 0
    static let activityDrop: CGFloat = 26
    static let activityExtraWidth: CGFloat = 8
    static let sideCollapsedSize: CGFloat = 96
    static let sideExpandedSize: CGFloat = 268
    static let sideCollapsedRadius: CGFloat = 24
    static let sideExpandedRadius: CGFloat = 30

    /// Side card is a square only with a cover. No cover — crop the empty bottom.
    static func sideExpandedHeight(hasArtwork: Bool, showProgress: Bool) -> CGFloat {
        var height: CGFloat = 12 + 36 + 14
        if hasArtwork {
            height += 8 + 52
        }
        height += 8 + 50
        height += 8 + 24
        if showProgress {
            height += 8 + 32
        }
        if hasArtwork {
            return max(sideExpandedSize, height)
        }
        return height + 8
    }

    static func collapsedVisualSize(
        notch: CGSize,
        activity _: Bool,
        placement: IslandPlacement = .home
    ) -> CGSize {
        if isSide(placement) {
            return CGSize(width: sideCollapsedSize, height: sideCollapsedSize)
        }
        if hasPhysicalNotch, placement == .home {
            return CGSize(
                width: max(notch.width + activityExtraWidth, 268),
                height: notch.height + activityDrop
            )
        }
        return CGSize(width: max(notch.width, 268), height: max(notch.height, 36))
    }

    static var hasPhysicalNotch: Bool {
        guard let screen = targetScreen else { return false }
        return hasPhysicalNotch(on: screen)
    }

    static var expandedWidth: CGFloat {
        guard let screen = targetScreen else { return expandedSize.width }
        return min(expandedSize.width, max(300, screen.visibleFrame.width - 56))
    }

    private struct Cache {
        let screen: NSScreen
        let screenFrame: NSRect
        let notch: NSRect
    }

    private static var cache: Cache?

    static func refreshCache() {
        cache = nil
        guard let screen = resolveTargetScreen() else { return }
        cache = Cache(
            screen: screen,
            screenFrame: screen.frame,
            notch: resolveNotchBounds(on: screen)
        )
    }

    static var targetScreen: NSScreen? {
        if cache == nil { refreshCache() }
        return cache?.screen
    }

    static let hardwareModel: String = {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }()

    static var macOSVersionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.patchVersion == 0 {
            return "\(version.majorVersion).\(version.minorVersion)"
        }
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static var machineSummary: String {
        "\(marketingName) · macOS \(macOSVersionString)"
    }

    static func collapsedSize(for screen: NSScreen) -> CGSize {
        if hasPhysicalNotch(on: screen) {
            return notchBounds(on: screen).size
        }
        return floatingCollapsedSize
    }

    static func notchBounds(on screen: NSScreen) -> NSRect {
        if let cache, cache.screenFrame == screen.frame {
            return cache.notch
        }
        return resolveNotchBounds(on: screen)
    }

    static func islandAnchor(on screen: NSScreen) -> NSRect {
        if hasPhysicalNotch(on: screen) {
            return notchBounds(on: screen)
        }
        let size = floatingCollapsedSize
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - floatingTopGap - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func islandSize(
        expanded: Bool,
        collapsed: CGSize,
        activity: Bool,
        expandedHeight: CGFloat,
        placement: IslandPlacement
    ) -> CGSize {
        if isSide(placement) {
            if expanded {
                return CGSize(width: sideExpandedSize, height: expandedHeight)
            }
            return CGSize(width: sideCollapsedSize, height: sideCollapsedSize)
        }
        return expanded
            ? CGSize(width: expandedWidth, height: expandedHeight)
            : collapsedVisualSize(notch: collapsed, activity: activity, placement: placement)
    }

    static func isSide(_ placement: IslandPlacement) -> Bool {
        placement == .left || placement == .right
    }

    static func windowFrame(for screen: NSScreen) -> NSRect {
        windowFrame(for: screen, state: nil, mouse: nil)
    }

    static func windowFrame(for screen: NSScreen, state: IslandState?, mouse: NSPoint?) -> NSRect {
        let placement = state?.dockedPlacement ?? .home
        var width = max(expandedWidth, islandAnchor(on: screen).width + 48)
        var height = max(expandedSize.height, state?.expandedHeight ?? 176)
            + editChromeGap + editTraySize.height
        if isSide(placement) {
            width = max(width, sideExpandedSize + editChromeGap + editSideTraySize.width + 24)
        }
        if let state, state.isRelocating, state.magnet == nil {
            let point = mouse ?? NSEvent.mouseLocation
            return NSRect(
                x: point.x - width / 2,
                y: point.y - height / 2,
                width: width,
                height: height
            )
        }
        if placement == .home {
            let anchor = islandAnchor(on: screen)
            let topGap = hasPhysicalNotch(on: screen) ? 0 : floatingTopGap
            return NSRect(
                x: anchor.midX - width / 2,
                y: screen.frame.maxY - height - topGap,
                width: width,
                height: height
            )
        }
        let along = state?.along ?? 0.5
        let expanded = state?.isExpanded == true
        let pill = pillScreenFrame(
            expanded: expanded,
            activity: state?.showsActivity ?? true,
            expandedHeight: state?.expandedHeight ?? 176,
            collapsed: state?.collapsedSize ?? collapsedSize(for: screen),
            placement: placement,
            along: along,
            on: screen
        )
        let visible = screen.visibleFrame
        switch placement {
        case .home:
            return windowFrame(for: screen)
        case .bottom:
            return NSRect(
                x: pill.midX - width / 2,
                y: visible.minY,
                width: width,
                height: height
            )
        case .left:
            return NSRect(
                x: visible.minX,
                y: pill.midY - height / 2,
                width: width,
                height: height
            )
        case .right:
            return NSRect(
                x: visible.maxX - width,
                y: pill.midY - height / 2,
                width: width,
                height: height
            )
        }
    }

    static func pillRect(
        in bounds: NSRect,
        expanded: Bool,
        collapsed: CGSize,
        activity: Bool,
        expandedHeight: CGFloat,
        placement: IslandPlacement = .home,
        relocating: Bool = false,
        magnet: IslandPlacement? = nil
    ) -> NSRect {
        let edge: IslandPlacement? = relocating ? magnet : placement
        let size = islandSize(
            expanded: expanded,
            collapsed: collapsed,
            activity: activity,
            expandedHeight: expandedHeight,
            placement: edge ?? .home
        )
        if relocating, magnet == nil {
            return NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
        switch edge ?? .home {
        case .home:
            return NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.maxY - size.height,
                width: size.width,
                height: size.height
            )
        case .bottom:
            return NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.minY,
                width: size.width,
                height: size.height
            )
        case .left:
            return NSRect(
                x: bounds.minX,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        case .right:
            return NSRect(
                x: bounds.maxX - size.width,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
    }

    static func containsCursor(
        _ point: NSPoint,
        expanded: Bool,
        activity: Bool,
        expandedHeight: CGFloat,
        on screen: NSScreen,
        placement: IslandPlacement = .home,
        along: CGFloat = 0.5,
        collapsed: CGSize? = nil
    ) -> Bool {
        let frame = screen.frame
        guard frame.insetBy(dx: -8, dy: -8).contains(point) else { return false }

        if placement == .home {
            let notch = islandAnchor(on: screen)
            let gap = hasPhysicalNotch(on: screen) ? 0 : floatingTopGap
            let fromTop = frame.maxY - point.y - gap
            let fromCenter = abs(point.x - notch.midX)

            if expanded {
                return fromTop >= -4
                    && fromTop <= expandedHeight + 10
                    && fromCenter <= expandedWidth / 2 + 6
            }

            let visual = collapsedVisualSize(notch: notch.size, activity: activity, placement: .home)
            return fromTop >= -4
                && fromTop <= visual.height + 16
                && fromCenter <= visual.width / 2 + 8
        }

        let pill = pillScreenFrame(
            expanded: expanded,
            activity: activity,
            expandedHeight: expandedHeight,
            collapsed: collapsed ?? collapsedSize(for: screen),
            placement: placement,
            along: along,
            on: screen
        )
        return expanded
            ? pill.insetBy(dx: -6, dy: -10).contains(point)
            : pill.insetBy(dx: -8, dy: -16).contains(point)
    }

    static func collapsedPillFrame(
        activity: Bool,
        on screen: NSScreen,
        placement: IslandPlacement = .home,
        along: CGFloat = 0.5,
        collapsed: CGSize? = nil
    ) -> NSRect {
        pillScreenFrame(
            expanded: false,
            activity: activity,
            expandedHeight: 176,
            collapsed: collapsed ?? collapsedSize(for: screen),
            placement: placement,
            along: along,
            on: screen
        )
    }

    static func isOnCollapsedPill(
        _ point: NSPoint,
        activity: Bool,
        on screen: NSScreen,
        placement: IslandPlacement = .home,
        along: CGFloat = 0.5
    ) -> Bool {
        collapsedPillFrame(activity: activity, on: screen, placement: placement, along: along)
            .insetBy(dx: -2, dy: -2)
            .contains(point)
    }

    static func isDeepExpandZone(
        _ point: NSPoint,
        activity: Bool,
        on screen: NSScreen,
        placement: IslandPlacement = .home,
        along: CGFloat = 0.5
    ) -> Bool {
        let pill = collapsedPillFrame(activity: activity, on: screen, placement: placement, along: along)
        switch placement {
        case .home:
            guard point.x >= pill.minX + 8, point.x <= pill.maxX - 8 else { return false }
            let fromTop = screen.frame.maxY - point.y - (hasPhysicalNotch(on: screen) ? 0 : floatingTopGap)
            return fromTop >= -2 && fromTop <= pill.height / 3
        case .bottom:
            guard point.x >= pill.minX + 8, point.x <= pill.maxX - 8 else { return false }
            return point.y - pill.minY >= -2 && point.y - pill.minY <= pill.height / 3
        case .left:
            guard point.y >= pill.minY + 8, point.y <= pill.maxY - 8 else { return false }
            return point.x - pill.minX >= -2 && point.x - pill.minX <= pill.width / 3
        case .right:
            guard point.y >= pill.minY + 8, point.y <= pill.maxY - 8 else { return false }
            return pill.maxX - point.x >= -2 && pill.maxX - point.x <= pill.width / 3
        }
    }

    static func mosesCursorInPill(
        _ point: NSPoint,
        activity: Bool,
        on screen: NSScreen,
        placement: IslandPlacement = .home,
        along: CGFloat = 0.5
    ) -> CGPoint? {
        guard placement == .home else { return nil }
        let pill = collapsedPillFrame(activity: activity, on: screen, placement: .home, along: along)
        let reach = NSRect(
            x: pill.minX - 18,
            y: pill.minY - 36,
            width: pill.width + 36,
            height: pill.height + 40
        )
        guard reach.contains(point) else { return nil }
        if isDeepExpandZone(point, activity: activity, on: screen, placement: .home, along: along) { return nil }
        let x = min(max(point.x - pill.minX, 18), pill.width - 18)
        let yFromBottom = point.y - pill.minY
        let swiftY = pill.height - yFromBottom
        return CGPoint(x: x, y: swiftY)
    }

    static func pillScreenFrame(
        expanded: Bool,
        activity: Bool,
        expandedHeight: CGFloat,
        collapsed: CGSize,
        placement: IslandPlacement,
        along: CGFloat,
        on screen: NSScreen
    ) -> NSRect {
        let size = islandSize(
            expanded: expanded,
            collapsed: collapsed,
            activity: activity,
            expandedHeight: expandedHeight,
            placement: placement
        )
        if placement == .home {
            let notch = islandAnchor(on: screen)
            let gap = hasPhysicalNotch(on: screen) ? 0 : floatingTopGap
            return NSRect(
                x: notch.midX - size.width / 2,
                y: screen.frame.maxY - size.height - gap,
                width: size.width,
                height: size.height
            )
        }
        let visible = screen.visibleFrame
        switch placement {
        case .home:
            return .zero
        case .bottom:
            return NSRect(
                x: alongOrigin(along, length: size.width, lo: visible.minX, hi: visible.maxX),
                y: visible.minY,
                width: size.width,
                height: size.height
            )
        case .left:
            return NSRect(
                x: visible.minX,
                y: alongOrigin(along, length: size.height, lo: visible.minY, hi: visible.maxY),
                width: size.width,
                height: size.height
            )
        case .right:
            return NSRect(
                x: visible.maxX - size.width,
                y: alongOrigin(along, length: size.height, lo: visible.minY, hi: visible.maxY),
                width: size.width,
                height: size.height
            )
        }
    }

    static func alongOrigin(_ along: CGFloat, length: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        let span = hi - lo - length
        return lo + Swift.max(span, 0) * Swift.min(Swift.max(along, 0), 1)
    }

    static func alongValue(center: CGFloat, length: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        let span = hi - lo - length
        guard span > 1 else { return 0.5 }
        return Swift.min(Swift.max((center - length / 2 - lo) / span, 0), 1)
    }

    /// Nearest of left / right / bottom from the island center. Top is home, not a wall.
    static func nearestWallTarget(
        from point: NSPoint,
        on screen: NSScreen,
        collapsed: CGSize
    ) -> (placement: IslandPlacement, along: CGFloat, center: CGPoint) {
        let visible = screen.visibleFrame
        let left = point.x - visible.minX
        let right = visible.maxX - point.x
        let bottom = point.y - visible.minY
        let placement: IslandPlacement
        if left <= right && left <= bottom {
            placement = .left
        } else if right <= bottom {
            placement = .right
        } else {
            placement = .bottom
        }
        let visual = collapsedVisualSize(notch: collapsed, activity: true, placement: placement)
        let along: CGFloat
        switch placement {
        case .left, .right:
            along = alongValue(center: point.y, length: visual.height, lo: visible.minY, hi: visible.maxY)
        default:
            along = alongValue(center: point.x, length: visual.width, lo: visible.minX, hi: visible.maxX)
        }
        let pill = pillScreenFrame(
            expanded: false,
            activity: true,
            expandedHeight: 176,
            collapsed: collapsed,
            placement: placement,
            along: along,
            on: screen
        )
        return (placement, along, CGPoint(x: pill.midX, y: pill.midY))
    }

    static func snapTarget(mouse: NSPoint, on screen: NSScreen, enter: CGFloat, current: IslandPlacement?) -> (IslandPlacement, CGFloat)? {
        let visible = screen.visibleFrame
        let left = mouse.x - visible.minX
        let right = visible.maxX - mouse.x
        let bottom = mouse.y - visible.minY
        let leave = enter + 22
        func armed(_ distance: CGFloat, _ edge: IslandPlacement) -> Bool {
            if current == edge { return distance < leave }
            return distance < enter
        }

        var best: (IslandPlacement, CGFloat, CGFloat)?
        if armed(left, .left) {
            let along = alongValue(center: mouse.y, length: sideCollapsedSize, lo: visible.minY, hi: visible.maxY)
            best = (.left, along, left)
        }
        if armed(right, .right), best == nil || right < best!.2 {
            let along = alongValue(center: mouse.y, length: sideCollapsedSize, lo: visible.minY, hi: visible.maxY)
            best = (.right, along, right)
        }
        if armed(bottom, .bottom), best == nil || bottom < best!.2 {
            let along = alongValue(center: mouse.x, length: 268, lo: visible.minX, hi: visible.maxX)
            best = (.bottom, along, bottom)
        }
        if let best {
            return (best.0, best.1)
        }
        return nil
    }

    static func homeButtonFrame(on screen: NSScreen) -> NSRect {
        let size: CGFloat = 22
        let notch = islandAnchor(on: screen)
        if hasPhysicalNotch(on: screen) {
            let y = notch.midY - size / 2
            let left = notch.minX - size - 8
            if left >= screen.frame.minX + 6 {
                return NSRect(x: left, y: y, width: size, height: size)
            }
            return NSRect(x: notch.maxX + 8, y: y, width: size, height: size)
        }
        return NSRect(
            x: notch.midX - size / 2,
            y: screen.frame.maxY - floatingTopGap - size,
            width: size,
            height: size
        )
    }

    static func accessoryFrame(
        size: CGSize,
        gap: CGFloat,
        offsetX: CGFloat,
        pill: NSRect,
        placement: IslandPlacement
    ) -> NSRect {
        switch placement {
        case .home:
            return NSRect(
                x: pill.midX - size.width / 2 + offsetX,
                y: pill.minY - gap - size.height,
                width: size.width,
                height: size.height
            )
        case .bottom:
            return NSRect(
                x: pill.midX - size.width / 2 + offsetX,
                y: pill.maxY + gap,
                width: size.width,
                height: size.height
            )
        case .left:
            return NSRect(
                x: pill.maxX + gap,
                y: pill.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        case .right:
            return NSRect(
                x: pill.minX - gap - size.width,
                y: pill.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
    }

    static let editPencilSize = CGSize(width: 26, height: 26)
    static let editTraySize = CGSize(width: 300, height: 50)
    static let editSideTraySize = CGSize(width: 52, height: 220)
    static let editChromeGap: CGFloat = 10

    static func editChromeSize(editing: Bool, placement: IslandPlacement) -> CGSize {
        if !editing { return editPencilSize }
        return isSide(placement) ? editSideTraySize : editTraySize
    }

    static func showsEditChrome(expanded: Bool, editing: Bool, relocating: Bool) -> Bool {
        !relocating && editing
    }

    static func editChromeRect(
        in bounds: NSRect,
        expanded: Bool,
        collapsed: CGSize,
        activity: Bool,
        expandedHeight: CGFloat,
        placement: IslandPlacement,
        relocating: Bool,
        magnet: IslandPlacement?,
        editing: Bool
    ) -> NSRect {
        guard showsEditChrome(expanded: expanded, editing: editing, relocating: relocating) else {
            return .zero
        }
        let pill = pillRect(
            in: bounds,
            expanded: expanded,
            collapsed: collapsed,
            activity: activity,
            expandedHeight: expandedHeight,
            placement: placement,
            relocating: relocating,
            magnet: magnet
        )
        let edge = relocating ? (magnet ?? placement) : placement
        return accessoryFrame(
            size: editChromeSize(editing: editing, placement: edge),
            gap: editChromeGap,
            offsetX: 0,
            pill: pill,
            placement: edge
        )
    }

    static func editChromeScreenFrame(
        expanded: Bool,
        activity: Bool,
        expandedHeight: CGFloat,
        collapsed: CGSize,
        placement: IslandPlacement,
        along: CGFloat,
        editing: Bool,
        on screen: NSScreen
    ) -> NSRect {
        guard showsEditChrome(expanded: expanded, editing: editing, relocating: false) else {
            return .zero
        }
        let pill = pillScreenFrame(
            expanded: expanded,
            activity: activity,
            expandedHeight: expandedHeight,
            collapsed: collapsed,
            placement: placement,
            along: along,
            on: screen
        )
        return accessoryFrame(
            size: editChromeSize(editing: editing, placement: placement),
            gap: editChromeGap,
            offsetX: 0,
            pill: pill,
            placement: placement
        )
    }

    private static func resolveTargetScreen() -> NSScreen? {
        if let builtIn = NSScreen.screens.first(where: { $0.safeAreaInsets.top >= 22 }) {
            return builtIn
        }
        if #available(macOS 12.0, *) {
            if let notched = NSScreen.screens.first(where: {
                guard let live = liveNotchBounds(on: $0) else { return false }
                return isPlausible(live, on: $0)
            }) {
                return notched
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    static var keepsOwnerLayout: Bool {
        hardwareModel == "Mac16,12"
    }

    static var isKnownNotchedMac: Bool {
        family(for: hardwareModel) != .unknown
    }

    static func hasPhysicalNotch(on screen: NSScreen) -> Bool {
        if isKnownNotchedMac { return true }
        if let live = liveNotchBounds(on: screen), isPlausible(live, on: screen) {
            return true
        }
        return screen.safeAreaInsets.top >= 22
    }

    private static func resolveNotchBounds(on screen: NSScreen) -> NSRect {
        if let live = liveNotchBounds(on: screen), isPlausible(live, on: screen) {
            let modeled = modelNotchBounds(on: screen)
            if agrees(live, with: modeled) || hasPhysicalNotch(on: screen) {
                return live
            }
        }
        if hasPhysicalNotch(on: screen) {
            return modelNotchBounds(on: screen)
        }
        return islandAnchor(on: screen)
    }

    private static func liveNotchBounds(on screen: NSScreen) -> NSRect? {
        guard #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea
        else {
            return nil
        }

        let width = rightArea.minX - leftArea.maxX
        guard width > 0 else { return nil }

        let insetHeight = screen.safeAreaInsets.top
        let height = insetHeight > 0 ? insetHeight : min(max(leftArea.height, 1), 40)
        let x = leftArea.maxX
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func isPlausible(_ rect: NSRect, on screen: NSScreen) -> Bool {
        guard rect.width >= 110, rect.width <= 200 else { return false }
        guard rect.height >= 24, rect.height <= 40 else { return false }
        guard abs(rect.midX - screen.frame.midX) < 24 else { return false }
        guard abs(rect.maxY - screen.frame.maxY) < 2 else { return false }
        return true
    }

    private static func agrees(_ live: NSRect, with modeled: NSRect) -> Bool {
        let widthRatio = live.width / max(modeled.width, 1)
        return widthRatio > 0.82 && widthRatio < 1.18 && abs(live.midX - modeled.midX) < 16
    }

    private static func modelNotchBounds(on screen: NSScreen) -> NSRect {
        let size = modelNotchSize(on: screen)
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func modelNotchSize(on screen: NSScreen) -> CGSize {
        let profile = displayProfile(for: hardwareModel)
        let scale = screen.frame.width / profile.refWidth
        let width = (profile.notchWidth * scale).rounded()
        let inset = screen.safeAreaInsets.top
        let height = (inset >= 24 && inset <= 40) ? inset : (profile.notchHeight * scale).rounded()
        return CGSize(width: width, height: height)
    }

    private struct DisplayProfile {
        let refWidth: CGFloat
        let notchWidth: CGFloat
        let notchHeight: CGFloat
    }

    private static func displayProfile(for model: String) -> DisplayProfile {
        switch family(for: model) {
        case .air13:
            return DisplayProfile(refWidth: 1470, notchWidth: 155, notchHeight: 32)
        case .air15:
            return DisplayProfile(refWidth: 1710, notchWidth: 160, notchHeight: 32)
        case .pro14:
            return DisplayProfile(refWidth: 1512, notchWidth: 184, notchHeight: 32)
        case .pro16:
            return DisplayProfile(refWidth: 1728, notchWidth: 184, notchHeight: 32)
        case .unknown:
            return DisplayProfile(refWidth: 1470, notchWidth: 155, notchHeight: 32)
        }
    }

    private enum Family {
        case air13, air15, pro14, pro16, unknown
    }

    private static func family(for model: String) -> Family {
        switch model {
        case "Mac16,12", "Mac15,12", "Mac14,2":
            return .air13
        case "Mac16,13", "Mac15,13", "Mac14,15":
            return .air15
        case "Mac16,1", "Mac16,6", "Mac16,8",
             "Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10",
             "Mac14,5", "Mac14,7", "Mac14,9",
             "MacBookPro18,3", "MacBookPro18,4":
            return .pro14
        case "Mac16,5", "Mac16,7",
             "Mac15,7", "Mac15,9", "Mac15,11",
             "Mac14,6", "Mac14,10",
             "MacBookPro18,1", "MacBookPro18,2":
            return .pro16
        default:
            return .unknown
        }
    }

    private static var marketingName: String {
        switch hardwareModel {
        case "Mac16,12": return "MacBook Air 13\" M4"
        case "Mac16,13": return "MacBook Air 15\" M4"
        case "Mac15,12": return "MacBook Air 13\" M3"
        case "Mac15,13": return "MacBook Air 15\" M3"
        case "Mac14,2": return "MacBook Air 13\" M2"
        case "Mac14,15": return "MacBook Air 15\" M2"
        case "Mac16,1", "Mac16,6", "Mac16,8": return "MacBook Pro 14\" M4"
        case "Mac16,5", "Mac16,7": return "MacBook Pro 16\" M4"
        case "MacBookPro18,3", "MacBookPro18,4": return "MacBook Pro 14\" M1"
        case "MacBookPro18,1", "MacBookPro18,2": return "MacBook Pro 16\" M1"
        default:
            switch family(for: hardwareModel) {
            case .air13: return "MacBook Air 13\""
            case .air15: return "MacBook Air 15\""
            case .pro14: return "MacBook Pro 14\""
            case .pro16: return "MacBook Pro 16\""
            case .unknown: return hardwareModel
            }
        }
    }
}
