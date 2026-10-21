import Combine
import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

final class TodoManager: ObservableObject {

    @Published private(set) var items: [TodoItem] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var completingIDs: Set<UUID> = []
    @Published var isOpen = false
    @Published var panelSize: CGSize
    @Published var panelOrigin: CGPoint?
    @Published var userPlaced = false
    @Published var isResizing = false
    @Published private(set) var confettiToken = 0

    var pinnedLeft: CGFloat = 0
    var pinnedTop: CGFloat = 0
    var onLiveFrame: (() -> Void)?

    static let defaultPanelSize = CGSize(width: 330, height: 380)
    static let minPanelSize = CGSize(width: 280, height: 240)
    static let maxPanelSize = CGSize(width: 460, height: 640)

    private static let itemsKey = "todo.items"
    private static let widthKey = "todo.panel.w"
    private static let heightKey = "todo.panel.h"
    private static let xKey = "todo.panel.x"
    private static let yKey = "todo.panel.y"
    private static let placedKey = "todo.panel.placed"

    init() {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: Self.widthKey)
        let height = defaults.double(forKey: Self.heightKey)
        if width >= Self.minPanelSize.width, height >= Self.minPanelSize.height {
            panelSize = CGSize(width: width, height: height)
        } else {
            panelSize = Self.defaultPanelSize
        }
        if defaults.bool(forKey: Self.placedKey) {
            userPlaced = true
            panelOrigin = CGPoint(
                x: defaults.double(forKey: Self.xKey),
                y: defaults.double(forKey: Self.yKey)
            )
        }
        if let data = defaults.data(forKey: Self.itemsKey),
           let saved = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = saved
        }
    }

    var selectedCount: Int { selectedIDs.count }
    var hasSelection: Bool { !selectedIDs.isEmpty }
    var pendingCount: Int { items.count }

    func toggle() {
        isOpen.toggle()
    }

    @discardableResult
    func add(_ raw: String) -> TodoItem? {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let item = TodoItem(title: title)
        items.append(item)
        persistItems()
        return item
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        selectedIDs.remove(id)
        persistItems()
    }

    func toggleSelection(_ id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func markSelectedCompleted() {
        let ids = selectedIDs
        guard !ids.isEmpty else { return }
        selectedIDs.removeAll()
        completingIDs.formUnion(ids)
        confettiToken += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.items.removeAll { ids.contains($0.id) }
            self.completingIDs.subtract(ids)
            self.persistItems()
        }
    }

    func setPanelSize(_ size: CGSize) {
        let next = clamped(size)
        guard next != panelSize else { return }
        panelSize = next
    }

    func beginResize(left: CGFloat, top: CGFloat) {
        pinnedLeft = left
        pinnedTop = top
        isResizing = true
    }

    func liveResize(from start: CGSize, mouse: CGPoint, origin: CGPoint) {
        setPanelSize(
            CGSize(
                width: start.width + (mouse.x - origin.x),
                height: start.height + (origin.y - mouse.y)
            )
        )
        onLiveFrame?()
    }

    func endResize() {
        isResizing = false
        userPlaced = true
        rememberOrigin(CGPoint(x: pinnedLeft, y: pinnedTop - panelSize.height))
        persistPanel()
    }

    func beginMove(origin: CGPoint) {
        userPlaced = true
        panelOrigin = origin
    }

    func liveMove(from start: CGPoint, mouse: CGPoint, origin: CGPoint) {
        panelOrigin = CGPoint(
            x: start.x + (mouse.x - origin.x),
            y: start.y + (mouse.y - origin.y)
        )
        onLiveFrame?()
    }

    func endMove() {
        persistPanel()
    }

    func rememberOrigin(_ origin: CGPoint) {
        panelOrigin = origin
    }

    func persistPanel() {
        let defaults = UserDefaults.standard
        defaults.set(panelSize.width, forKey: Self.widthKey)
        defaults.set(panelSize.height, forKey: Self.heightKey)
        if let panelOrigin {
            defaults.set(panelOrigin.x, forKey: Self.xKey)
            defaults.set(panelOrigin.y, forKey: Self.yKey)
            defaults.set(true, forKey: Self.placedKey)
        }
    }

    func clamped(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, Self.minPanelSize.width), Self.maxPanelSize.width),
            height: min(max(size.height, Self.minPanelSize.height), Self.maxPanelSize.height)
        )
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.itemsKey)
    }
}
