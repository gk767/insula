import SwiftUI

struct ConfettiOverlayView: View {
    @ObservedObject var todo: TodoManager

    @State private var pieces: [ConfettiPiece] = []
    @State private var startedAt = Date()
    @State private var isRunning = false
    @State private var runID = 0

    var body: some View {
        ZStack {
            if isRunning {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startedAt)
                        for piece in pieces {
                            draw(piece, at: elapsed, in: size, context: &context)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .background(Color.clear)
        .onChange(of: todo.confettiToken) { _, _ in
            startRun()
        }
        .accessibilityHidden(true)
    }

    private func startRun() {
        runID += 1
        let current = runID
        pieces = (0..<84).map { _ in ConfettiPiece.random() }
        startedAt = Date()
        isRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            guard runID == current else { return }
            isRunning = false
        }
    }

    private func draw(
        _ piece: ConfettiPiece,
        at elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let age = elapsed - piece.delay
        guard age > 0, age < piece.duration, size.width > 1, size.height > 1 else { return }

        let progress = CGFloat(age / piece.duration)
        let x = size.width * piece.x
            + piece.drift * size.width * progress
            + sin(CGFloat(age) * piece.swayFrequency + piece.phase) * piece.sway
        let y = -34 + (size.height + 68) * progress

        let fadeIn = min(1, CGFloat(age) / 0.18)
        let fadeOut = min(1, max(0, CGFloat(piece.duration - age) / 0.5))
        let opacity = 0.78 * fadeIn * fadeOut
        guard opacity > 0.01 else { return }

        context.drawLayer { layer in
            layer.translateBy(x: x, y: y)
            layer.rotate(by: .radians(piece.initialRotation + piece.spin * age))
            layer.opacity = opacity

            let rect = CGRect(
                x: -piece.width / 2,
                y: -piece.height / 2,
                width: piece.width,
                height: piece.height
            )
            layer.fill(
                Path(roundedRect: rect, cornerRadius: 1.1),
                with: .color(piece.color)
            )
        }
    }
}

private struct ConfettiPiece {
    var x: CGFloat
    var delay: Double
    var duration: Double
    var drift: CGFloat
    var sway: CGFloat
    var swayFrequency: CGFloat
    var phase: CGFloat
    var width: CGFloat
    var height: CGFloat
    var color: Color
    var initialRotation: Double
    var spin: Double

    static func random() -> ConfettiPiece {
        ConfettiPiece(
            x: .random(in: 0...1),
            delay: .random(in: 0...0.55),
            duration: .random(in: 2.0...3.0),
            drift: .random(in: -0.16...0.16),
            sway: .random(in: 6...22),
            swayFrequency: .random(in: 1.1...2.4),
            phase: .random(in: 0...(2 * .pi)),
            width: .random(in: 3.5...7.5),
            height: .random(in: 2.2...4.6),
            color: palette.randomElement() ?? .white,
            initialRotation: .random(in: 0...(2 * .pi)),
            spin: .random(in: -4.2...4.2)
        )
    }

    private static let palette: [Color] = [
        Color(red: 0.99, green: 0.42, blue: 0.42),
        Color(red: 0.99, green: 0.80, blue: 0.34),
        Color(red: 0.42, green: 0.86, blue: 0.55),
        Color(red: 0.42, green: 0.72, blue: 0.98),
        Color(red: 0.98, green: 0.55, blue: 0.78),
        Color(red: 0.70, green: 0.60, blue: 0.98),
        Color(red: 0.96, green: 0.96, blue: 0.96)
    ]
}
