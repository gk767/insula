import AppKit
import SwiftUI

struct LyricsView: View {
    @ObservedObject var lyrics: LyricsManager
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var guide: IslandGuide

    @State private var dragStartSize: CGSize?
    @State private var dragStartMouse: CGPoint?

    private let lineAnimation: Double = 0.18
    private let syncLead: Double = 0.7

    private var scale: CGFloat {
        let base = LyricsManager.defaultPanelSize
        let value = sqrt(
            (lyrics.panelSize.width / base.width) * (lyrics.panelSize.height / base.height)
        )
        return min(max(value, 0.72), 2.4)
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26 * min(scale, 1.35), style: .continuous)
    }

    var body: some View {
        Group {
            if lyrics.hasTimestamps || usingDemoLyrics {
                timedLyrics
            } else {
                plainLyrics
            }
        }
        .background {
            card.fill(.ultraThinMaterial)
            card.fill(Color.black.opacity(0.28))
        }
        .overlay {
            card.stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .clipShape(card)
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .overlay(alignment: .bottomLeading) {
            if lyrics.hasTimestamps || guide.showsLyricsChrome {
                syncButtons
            }
        }
        .overlay(alignment: .topLeading) {
            closeButton
                .zIndex(20)
        }
        .environment(\.colorScheme, .dark)
        .environment(\.islandGuide, guide)
        .reportGuideFrame(.lyricsPanel, guide: guide, window: lyricsWindow)
    }

    private var usingDemoLyrics: Bool {
        guide.showsLyricsChrome
    }

    private var shownLines: [LyricsManager.Line] {
        usingDemoLyrics ? Self.demoLines : lyrics.lines
    }

    private static let demoLines: [LyricsManager.Line] = [
        .init(id: 0, time: 0, text: "★★★★★★★★★★★★"),
        .init(id: 1, time: 3, text: "★ ★ ★ ★ ★ ★ ★"),
        .init(id: 2, time: 6, text: "★★★★★★★★★"),
        .init(id: 3, time: 9, text: "★ ★ ★ ★ ★ ★"),
        .init(id: 4, time: 12, text: "★★★★★★★★★★"),
        .init(id: 5, time: 15, text: "★ ★ ★ ★ ★ ★ ★"),
        .init(id: 6, time: 18, text: "★★★★★★★★"),
    ]

    private var timedLyrics: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !lyrics.isOpen && !usingDemoLyrics)) { context in
            let elapsed = nowPlaying.elapsed(at: context.date) + syncLead + lyrics.trackOffset
            let index = usingDemoLyrics
                ? demoIndex(at: elapsed)
                : lyrics.index(at: elapsed, duration: nowPlaying.duration)
            let fontSize = 12 * scale
            let gap = 8 * scale
            let row = fontSize * 1.28 * 2

            GeometryReader { geo in
                VStack(spacing: gap) {
                    ForEach(shownLines) { item in
                        lyricLine(
                            displayText(item.text),
                            size: fontSize,
                            opacity: lineOpacity(item.id, current: index)
                        )
                        .frame(maxWidth: .infinity, minHeight: row, maxHeight: row)
                    }
                }
                .offset(y: geo.size.height / 2 - row / 2 - CGFloat(index) * (row + gap))
                .animation(.easeInOut(duration: lineAnimation), value: index)
            }
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 16 * scale)
            .clipped()
        }
    }

    @ViewBuilder
    private var plainLyrics: some View {
        let fontSize = 12 * scale
        ScrollView {
            VStack(alignment: .center, spacing: 8 * scale) {
                ForEach(shownLines) { item in
                    lyricLine(displayText(item.text), size: fontSize, opacity: 0.86, lineLimit: nil)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20 * scale)
            .padding(.top, 28 * scale)
            .padding(.bottom, 16 * scale)
        }
    }

    private var lyricsWindow: NSWindow? {
        (NSApp.delegate as? AppDelegate)?.lyricsWindow
    }

    private var syncButtons: some View {
        HStack(spacing: 6) {
            Button {
                lyrics.nudge(-0.1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Позже")

            if abs(lyrics.trackOffset) >= 0.05 {
                Text(offsetLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.45))
            }

            Button {
                lyrics.nudge(0.1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Раньше")
        }
        .padding(10)
        .reportGuideFrame(.lyricsSync, guide: guide, window: lyricsWindow)
    }

    private var offsetLabel: String {
        let value = lyrics.trackOffset
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))с"
    }

    private var closeButton: some View {
        Button {
            lyrics.isOpen = false
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.88, green: 0.30, blue: 0.28).opacity(0.72))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .frame(width: 14, height: 14)
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.black.opacity(0.48))
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .padding(10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouse = NSEvent.mouseLocation
                        if dragStartSize == nil {
                            dragStartSize = lyrics.panelSize
                            dragStartMouse = mouse
                            if let window = lyricsWindow {
                                lyrics.beginResize(left: window.frame.minX, top: window.frame.maxY)
                            }
                        }
                        guard let startSize = dragStartSize, let startMouse = dragStartMouse else { return }
                        lyrics.liveResize(from: startSize, mouse: mouse, origin: startMouse)
                    }
                    .onEnded { _ in
                        lyrics.endResize()
                        dragStartSize = nil
                        dragStartMouse = nil
                    }
            )
            .onHover { inside in
                if inside {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
            .reportGuideFrame(.lyricsResize, guide: guide, window: lyricsWindow)
    }

    private func demoIndex(at elapsed: Double) -> Int {
        let count = Self.demoLines.count
        guard count > 1 else { return 0 }
        let step = 3.0
        return min(count - 1, max(0, Int(elapsed / step)))
    }

    private func lineOpacity(_ id: Int, current: Int) -> Double {
        switch abs(id - current) {
        case 0: return 1
        case 1: return 0.28
        default: return 0
        }
    }

    private func lyricLine(
        _ text: String,
        size: CGFloat,
        opacity: Double,
        lineLimit: Int? = 2
    ) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(opacity))
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func displayText(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? " " : value
    }
}

protocol LyricsHost {}

final class LyricsHostingView<Content: View>: NSHostingView<Content>, LyricsHost {
    var handleLength: CGFloat = 28

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        if shouldMoveWindow(at: point) {
            return self
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if shouldMoveWindow(at: point) {
            window?.performDrag(with: event)
            if let origin = window?.frame.origin {
                (NSApp.delegate as? AppDelegate)?.lyrics.userPlaced = true
                (NSApp.delegate as? AppDelegate)?.lyrics.rememberOrigin(origin)
                (NSApp.delegate as? AppDelegate)?.lyrics.persistPanel()
            }
            return
        }
        super.mouseDown(with: event)
    }

    private func topLeft(_ point: NSPoint) -> NSPoint {
        if isFlipped { return point }
        return NSPoint(x: point.x, y: bounds.height - point.y)
    }

    private func shouldMoveWindow(at point: NSPoint) -> Bool {
        if isChrome(at: point) { return false }
        if (NSApp.delegate as? AppDelegate)?.lyrics.hasTimestamps == true {
            return true
        }
        return topLeft(point).y < 32
    }

    private func isChrome(at point: NSPoint) -> Bool {
        let p = topLeft(point)
        let width = bounds.width
        let height = bounds.height
        if p.x < 42, p.y < 42 { return true }
        if p.x > width - 40, p.y > height - 40 { return true }
        if (NSApp.delegate as? AppDelegate)?.lyrics.hasTimestamps == true,
           p.x < 120, p.y > height - 52 {
            return true
        }
        return false
    }
}
