import AppKit
import SwiftUI

struct GuideOverlayView: View {
    @ObservedObject var guide: IslandGuide
    var onLayout: (CGRect, CGRect, CGRect) -> Void

    @State private var cardSize = CGSize(width: 360, height: 320)
    @State private var guideTextHeight: CGFloat = 180

    private var overlayFrame: CGRect {
        NSApp.windows.first(where: { $0 is GuidePanelWindow })?.frame
            ?? NotchGeometry.targetScreen?.frame
            ?? .zero
    }

    var body: some View {
        GeometryReader { geo in
            let insets = safeInsets(canvas: geo.size)
            let maxCardHeight = max(240, geo.size.height - insets.top - insets.bottom)
            let width = min(360, geo.size.width - insets.left - insets.right)
            // Grow with content; only clamp to the safe screen area.
            let height = min(max(cardSize.height, 220), maxCardHeight)
            let fitted = CGSize(width: width, height: height)
            let hole = swiftRect(guide.holeScreenRect, canvas: geo.size)
            let island = swiftRect(guide.islandScreenRect, canvas: geo.size)
            let card = placedCard(hole: hole, island: island, size: fitted, canvas: geo.size, insets: insets)
            let escape = escapeChipFrame(canvas: geo.size, insets: insets)
            let textMax = max(200, maxCardHeight - 154)

            ZStack(alignment: .topLeading) {
                GuideDimShape(hole: hole)
                    .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                if hole.width > 2, hole.height > 2, guide.currentSpot != .end {
                    RoundedRectangle(cornerRadius: highlightRadius(hole), style: .continuous)
                        .stroke(Color.white.opacity(0.94), lineWidth: 1.5)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false)

                    if guide.showsCursorDemo {
                        GuideCursorPlay(target: hole, drag: guide.currentSpot == .relocateDock)
                            .id("\(guide.stepIndex)-\(guideCoord(hole.midX))-\(guideCoord(hole.midY))")
                            .allowsHitTesting(false)
                    }
                }

                cardView(textMaxHeight: textMax, width: width)
                    .background {
                        GeometryReader { cardGeo in
                            Color.clear.preference(key: GuideCardSizeKey.self, value: cardGeo.size)
                        }
                    }
                    .frame(width: fitted.width, height: fitted.height, alignment: .topLeading)
                    .position(x: card.midX, y: card.midY)

                escapeChip
                    .position(x: escape.midX, y: escape.midY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onPreferenceChange(GuideCardSizeKey.self) { size in
                guard size.width > 1, size.height > 1 else { return }
                let next = CGSize(
                    width: width,
                    height: min(max(size.height, 220), maxCardHeight)
                )
                guard abs(next.height - cardSize.height) > 0.5 else { return }
                DispatchQueue.main.async {
                    cardSize = next
                }
            }
            .onAppear { onLayout(hole, card, escape) }
            .onChange(of: guide.isActive) { _, _ in onLayout(hole, card, escape) }
            .onChange(of: guide.stepIndex) { _, _ in
                guideTextHeight = 180
                cardSize = CGSize(width: width, height: min(420, maxCardHeight))
                onLayout(hole, card, escape)
            }
            .onChange(of: guide.holeScreenRect) { _, _ in onLayout(hole, card, escape) }
            .onChange(of: cardSize) { _, _ in onLayout(hole, card, escape) }
            .onChange(of: guide.language) { _, _ in
                guideTextHeight = 180
                cardSize = CGSize(width: width, height: min(420, maxCardHeight))
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var escapeChip: some View {
        Button(action: { guide.skip() }) {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                Text(guide.language.skip)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 128, height: 36, alignment: .trailing)
    }

    private func languageChipRow(_ items: [GuideLanguage]) -> some View {
        HStack(spacing: 5) {
            ForEach(items) { item in
                Text(item.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(guide.language == item ? .black : .white.opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(guide.language == item ? Color.white : Color.white.opacity(0.08))
                    )
                    .contentShape(Capsule())
                    .onTapGesture { guide.setLanguage(item) }
            }
        }
    }

    private func cardView(textMaxHeight: CGFloat, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                languageChipRow(Array(GuideLanguage.allCases.prefix(3)))
                languageChipRow(Array(GuideLanguage.allCases.dropFirst(3)))
            }

            // Prefer showing the full copy; scroll only if it still exceeds the screen budget.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.copy.why)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(guide.copy.how)
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background {
                    GeometryReader { textGeo in
                        Color.clear.preference(key: GuideTextSizeKey.self, value: textGeo.size.height)
                    }
                }
            }
            .frame(height: min(textMaxHeight, max(guideTextHeight, 1)))

            HStack(alignment: .center, spacing: 10) {
                Text("\(guide.stepIndex + 1)/\(max(guide.steps.count, 1))")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.38))
                Spacer(minLength: 8)
                Button(action: { guide.next() }) {
                    Text(guide.isLast ? guide.language.done : guide.language.next)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule(style: .continuous).fill(Color.white))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: width, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: true)
        .onPreferenceChange(GuideTextSizeKey.self) { height in
            guard height > 1, abs(height - guideTextHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                guideTextHeight = height
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.48))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 22, y: 10)
    }

    private func highlightRadius(_ hole: CGRect) -> CGFloat {
        min(12, hole.height / 2, hole.width / 2)
    }

    private func safeInsets(canvas _: CGSize) -> (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        guard let screen = NotchGeometry.targetScreen else {
            return (52, 28, 22, 22)
        }
        let frame = screen.frame
        let visible = screen.visibleFrame
        // Keep the card fully below the menu bar / notch and above the Dock.
        let top = max(52, frame.maxY - visible.maxY + 10)
        let bottom = max(28, visible.minY - frame.minY + 10)
        return (top, bottom, 22, 22)
    }

    private func escapeChipFrame(
        canvas: CGSize,
        insets: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
    ) -> CGRect {
        CGRect(
            x: canvas.width - insets.right - 128,
            y: insets.top,
            width: 128,
            height: 36
        )
    }

    private func swiftRect(_ screen: CGRect, canvas: CGSize) -> CGRect {
        let origin = overlayFrame
        guard screen.width > 1, screen.height > 1, origin.width > 1, canvas.height > 1 else {
            return .null
        }
        return CGRect(
            x: screen.minX - origin.minX,
            y: canvas.height - (screen.maxY - origin.minY),
            width: screen.width,
            height: screen.height
        )
    }

    private func placedCard(
        hole: CGRect,
        island: CGRect,
        size: CGSize,
        canvas: CGSize,
        insets: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
    ) -> CGRect {
        let gap: CGFloat = 22
        let block = island.width > 2 ? island : hole
        var rect = CGRect(origin: .zero, size: size)

        func clamp(_ value: CGRect) -> CGRect {
            var next = value
            next.origin.x = min(max(next.origin.x, insets.left), canvas.width - size.width - insets.right)
            next.origin.y = min(max(next.origin.y, insets.top), canvas.height - size.height - insets.bottom)
            if next.origin.y < insets.top { next.origin.y = insets.top }
            if next.maxY > canvas.height - insets.bottom {
                next.origin.y = max(insets.top, canvas.height - insets.bottom - size.height)
            }
            return next
        }

        if hole.width < 2 || hole.height < 2 || guide.currentSpot == .end {
            rect.origin.x = min(canvas.width - size.width - insets.right, max(insets.left, canvas.width * 0.62))
            rect.origin.y = insets.top + 8
            return clamp(rect)
        }

        if guide.currentSpot == .relocateHome {
            return clamp(placedCardNearHome(hole: hole, size: size, canvas: canvas, insets: insets))
        }

        let rightX = (block.width > 2 ? block.maxX : hole.maxX) + gap
        let leftX = (block.width > 2 ? block.minX : hole.minX) - gap - size.width
        if rightX + size.width <= canvas.width - insets.right {
            rect.origin.x = rightX
        } else if leftX >= insets.left {
            rect.origin.x = leftX
        } else {
            rect.origin.x = canvas.width - size.width - insets.right
        }

        let anchor = island.width > 2 ? island : hole
        // Prefer just under the island; never above the safe top inset.
        rect.origin.y = max(insets.top, max(anchor.maxY, hole.maxY) + 16)
        if rect.maxY > canvas.height - insets.bottom {
            rect.origin.y = max(insets.top, canvas.height - insets.bottom - size.height)
        }
        if rect.intersects(hole.insetBy(dx: -12, dy: -12))
            || (anchor.width > 2 && rect.intersects(anchor.insetBy(dx: -10, dy: -10))) {
            // Side placement already chosen; nudge further down or to safe top.
            rect.origin.y = max(insets.top, max(anchor.maxY, hole.maxY) + 20)
        }
        return clamp(rect)
    }

    private func placedCardNearHome(
        hole: CGRect,
        size: CGSize,
        canvas: CGSize,
        insets: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
    ) -> CGRect {
        var rect = CGRect(origin: .zero, size: size)
        let gap: CGFloat = 14
        let leftX = hole.minX - gap - size.width
        let rightX = hole.maxX + gap
        if leftX >= insets.left {
            rect.origin.x = leftX
        } else if rightX + size.width <= canvas.width - insets.right {
            rect.origin.x = rightX
        } else {
            rect.origin.x = insets.left
        }
        rect.origin.y = max(insets.top, hole.maxY + gap)
        return rect
    }
}

private func guideCoord(_ value: CGFloat) -> Int {
    guard value.isFinite else { return 0 }
    return Int(value.rounded())
}

private struct GuideCardSizeKey: PreferenceKey {
    static var defaultValue = CGSize(width: 360, height: 320)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct GuideTextSizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 180

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GuideDimShape: Shape {
    var hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if hole.width > 2, hole.height > 2 {
            let radius = max(0, min(12, hole.height / 2, hole.width / 2))
            if radius.isFinite, hole.origin.x.isFinite, hole.origin.y.isFinite {
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
            }
        }
        return path
    }
}

private struct GuideCursorPlay: View {
    var target: CGRect
    var drag: Bool

    @State private var point = CGPoint.zero
    @State private var pressed = false

    var body: some View {
        GuidePointerShape()
            .fill(Color.white)
            .overlay {
                GuidePointerShape().stroke(Color.black.opacity(0.85), lineWidth: 0.8)
            }
            .frame(width: 16, height: 22)
            .scaleEffect(pressed ? 0.82 : 1, anchor: .topLeading)
            .position(point)
            .task(id: "\(drag)-\(guideCoord(target.midX))-\(guideCoord(target.midY))") {
                await run()
            }
    }

    @MainActor
    private func run() async {
        let click = CGPoint(x: target.midX + 4, y: target.midY + 4)
        let start = CGPoint(x: target.midX + 20, y: target.maxY + 26)
        let end = CGPoint(x: click.x, y: click.y + (drag ? 88 : 0))
        while !Task.isCancelled {
            point = start
            pressed = false
            withAnimation(.easeInOut(duration: 0.32)) { point = click }
            try? await Task.sleep(nanoseconds: 380_000_000)
            for _ in 0..<3 {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.07)) { pressed = true }
                try? await Task.sleep(nanoseconds: 90_000_000)
                withAnimation(.easeInOut(duration: 0.07)) { pressed = false }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            if drag {
                withAnimation(.easeInOut(duration: 0.65)) { point = end }
                try? await Task.sleep(nanoseconds: 900_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

private struct GuidePointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.94))
        path.addLine(to: CGPoint(x: rect.maxX * 0.38, y: rect.maxY * 0.5))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.48))
        path.closeSubpath()
        return path
    }
}

final class GuideHostingView: NSHostingView<GuideOverlayView> {
    var hole: CGRect = .null
    var card: CGRect = .null
    var escape: CGRect = .null

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Guide overlay uses top-left SwiftUI coords; AppKit is bottom-left.
        let swiftPoint = CGPoint(x: point.x, y: bounds.height - point.y)

        if hits(card, swiftPoint) || hits(escape, swiftPoint) {
            return super.hitTest(point) ?? self
        }
        if hits(hole, swiftPoint) {
            return nil
        }
        // Backdrop: swallow the click (dismiss in mouseDown).
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let swiftPoint = CGPoint(x: point.x, y: bounds.height - point.y)
        if hits(card, swiftPoint) || hits(escape, swiftPoint) {
            super.mouseDown(with: event)
            return
        }
        if hits(hole, swiftPoint) {
            return
        }
        (NSApp.delegate as? AppDelegate)?.guide.skip()
    }

    private func hits(_ rect: CGRect, _ point: CGPoint) -> Bool {
        rect.width > 2 && rect.height > 2 && rect.insetBy(dx: -8, dy: -8).contains(point)
    }
}

final class GuidePanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            (NSApp.delegate as? AppDelegate)?.guide.skip()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            (NSApp.delegate as? AppDelegate)?.guide.next()
            return
        }
        super.keyDown(with: event)
    }
}
