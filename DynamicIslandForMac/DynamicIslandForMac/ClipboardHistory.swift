import AppKit
import Combine

final class ClipboardHistory: ObservableObject {

    struct Item: Identifiable, Equatable {
        let id: UUID
        let text: String
    }

    @Published private(set) var items: [Item] = []

    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var ignoreOwnWrite = false

    init() {
        ingestCurrent()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    func copyAgain(_ text: String) {
        ignoreOwnWrite = true
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        lastChangeCount = board.changeCount
        insert(text)
    }

    static func preview(_ text: String) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !trimmed.isEmpty else { return "…" }
        if trimmed.count <= 36 { return trimmed }
        return String(trimmed.prefix(35)) + "…"
    }

    private func poll() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if ignoreOwnWrite {
            ignoreOwnWrite = false
            return
        }
        ingestCurrent()
    }

    private func ingestCurrent() {
        guard var text = NSPasteboard.general.string(forType: .string) else { return }
        if text.count > 4000 {
            text = String(text.prefix(4000))
        }
        insert(text)
    }

    private func insert(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.removeAll { $0.text == trimmed }
        items.insert(Item(id: UUID(), text: trimmed), at: 0)
        if items.count > 5 {
            items = Array(items.prefix(5))
        }
    }
}
