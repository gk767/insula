import AppKit
import SwiftUI

struct GuideOverlayView: View {
    @ObservedObject var guide: IslandGuide
    var onLayout: (CGRect, CGRect) -> Void

    @State private var cardSize = CGSize(width: 312, height: 196)

    private var overlayFrame: CGRect {
        NSApp.windows.first(where: { $0 is GuidePanelWindow })?.frame
            ?? NotchGeometry.targetScreen?.frame
            ?? .zero
    }

    var body: some View {
        GeometryReader { geo in
            let hole = swiftRect(guide.holeScreenRect, canvas: geo.size)
            let island = swiftRect(guide.islandScreenRect, canvas: geo.size)
            let card = placedCard(hole: hole, island: island, size: cardSize, canvas: geo.size)

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

                cardView
                    .frame(width: cardSize.width, alignment: .topLeading)
                    .background {
                        GeometryReader { cardGeo in
                            Color.clear.preference(key: GuideCardSizeKey.self, value: cardGeo.size)
                        }
                    }
                    .position(x: card.midX, y: card.midY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onPreferenceChange(GuideCardSizeKey.self) { size in
                guard size.width > 1, size.height > 1, abs(size.height - cardSize.height) > 0.5 else { return }
                DispatchQueue.main.async {
                    cardSize = size
                }
            }
            .onAppear { onLayout(hole, card) }
            .onChange(of: guide.isActive) { _, _ in onLayout(hole, card) }
            .onChange(of: guide.stepIndex) { _, _ in onLayout(hole, card) }
            .onChange(of: guide.holeScreenRect) { _, _ in onLayout(hole, card) }
            .onChange(of: cardSize) { _, _ in onLayout(hole, card) }
        }
        .environment(\.colorScheme, .dark)
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

    private var cardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                languageChipRow(Array(GuideLanguage.allCases.prefix(3)))
                languageChipRow(Array(GuideLanguage.allCases.dropFirst(3)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(guide.copy.why)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(guide.copy.how)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 10) {
                Text("\(guide.stepIndex + 1)/\(max(guide.steps.count, 1))")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.38))
                Spacer(minLength: 8)
                if !guide.isLast {
                    Text(guide.language.skip)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.52))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { guide.skip() }
                }
                Text(guide.isLast ? guide.language.done : guide.language.next)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule(style: .continuous).fill(Color.white))
                    .contentShape(Capsule())
                    .onTapGesture { guide.next() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 312, alignment: .topLeading)
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

    private func placedCard(hole: CGRect, island: CGRect, size: CGSize, canvas: CGSize) -> CGRect {
        let margin: CGFloat = 22
        let gap: CGFloat = 22
        let block = island.width > 2 ? island : hole
        var rect = CGRect(origin: .zero, size: size)

        if hole.width < 2 || hole.height < 2 || guide.currentSpot == .end {
            rect.origin.x = min(canvas.width - size.width - margin, max(margin, canvas.width * 0.62))
            rect.origin.y = min(max(72, margin), canvas.height - size.height - margin)
            return rect
        }

        if guide.currentSpot == .relocateHome {
            return placedCardNearHome(hole: hole, size: size, canvas: canvas, margin: margin)
        }

        let rightX = (block.width > 2 ? block.maxX : hole.maxX) + gap
        let leftX = (block.width > 2 ? block.minX : hole.minX) - gap - size.width
        if rightX + size.width <= canvas.width - margin {
            rect.origin.x = rightX
        } else if leftX >= margin {
            rect.origin.x = leftX
        } else {
            rect.origin.x = canvas.width - size.width - margin
        }

        // Keep the card next to the island, not next to a missed hole in Xcode.
        let anchor = island.width > 2 ? island : hole
        rect.origin.y = max(margin, min(anchor.minY, canvas.height - size.height - margin))
        if rect.intersects(hole.insetBy(dx: -16, dy: -16))
            || (anchor.width > 2 && rect.intersects(anchor.insetBy(dx: -12, dy: -12))) {
            rect.origin.y = max(anchor.maxY, hole.maxY) + 16
        }
        rect.origin.x = min(max(rect.origin.x, margin), canvas.width - size.width - margin)
        rect.origin.y = min(max(rect.origin.y, margin), canvas.height - size.height - margin)
        return rect
    }

    private func placedCardNearHome(hole: CGRect, size: CGSize, canvas: CGSize, margin: CGFloat) -> CGRect {
        var rect = CGRect(origin: .zero, size: size)
        let gap: CGFloat = 14
        let leftX = hole.minX - gap - size.width
        let rightX = hole.maxX + gap
        if leftX >= margin {
            rect.origin.x = leftX
        } else if rightX + size.width <= canvas.width - margin {
            rect.origin.x = rightX
        } else {
            rect.origin.x = margin
        }
        rect.origin.y = hole.maxY + gap
        if rect.intersects(hole.insetBy(dx: -10, dy: -10)) {
            rect.origin.y = hole.maxY + gap
        }
        rect.origin.x = min(max(rect.origin.x, margin), canvas.width - size.width - margin)
        rect.origin.y = min(max(rect.origin.y, margin), canvas.height - size.height - margin)
        return rect
    }
}

private func guideCoord(_ value: CGFloat) -> Int {
    guard value.isFinite else { return 0 }
    return Int(value.rounded())
}

private struct GuideCardSizeKey: PreferenceKey {
    static var defaultValue = CGSize(width: 312, height: 196)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let flipped = CGPoint(x: point.x, y: bounds.height - point.y)
        if hits(hole, point) || hits(hole, flipped) {
            return nil
        }
        if hits(card, point) || hits(card, flipped) {
            return super.hitTest(point) ?? self
        }
        return nil
    }

    private func hits(_ rect: CGRect, _ point: CGPoint) -> Bool {
        rect.width > 2 && rect.height > 2 && rect.insetBy(dx: -10, dy: -10).contains(point)
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
        super.keyDown(with: event)
    }
}
