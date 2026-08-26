import Foundation
import Combine

final class IslandTimerManager: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var didFinish: Bool = false

    var onFinish: (() -> Void)?

    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        stop()
        remainingSeconds = seconds
        isRunning = true
        didFinish = false

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func cancel() {
        stop()
        remainingSeconds = 0
        didFinish = false
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func tick() {
        remainingSeconds -= 1
        guard remainingSeconds <= 0 else { return }
        remainingSeconds = 0
        stop()
        didFinish = true
        onFinish?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, !self.isRunning else { return }
            self.didFinish = false
        }
    }

    var formatted: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
