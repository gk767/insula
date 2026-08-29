import SwiftUI
import Combine

enum IslandPlacement: String {
    case home
    case left
    case right
    case bottom
}

enum IslandModule: String, CaseIterable, Identifiable {
    case timer
    case clipboard
    case lyrics
    case playlist
    case audioOutput
    case micMute
    case guide
    case schedule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Таймер"
        case .clipboard: return "Буфер обмена"
        case .lyrics: return "Текст песни"
        case .playlist: return "Актуальный плейлист"
        case .audioOutput: return "Куда играет звук"
        case .micMute: return "Микрофон"
        case .guide: return "Guide"
        case .schedule: return "Расписание"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .lyrics: return "quote.bubble"
        case .playlist: return "music.note.list"
        case .audioOutput: return "headphones"
        case .micMute: return "mic.fill"
        case .guide: return "questionmark"
        case .schedule: return "calendar"
        }
    }

    var isUtilityEar: Bool {
        switch self {
        case .schedule, .clipboard, .micMute, .guide:
            return true
        default:
            return false
        }
    }

    static let utilityEarModules: [IslandModule] = [.schedule, .clipboard, .micMute, .guide]
}

final class IslandState: ObservableObject {
    @Published var isHovering = false
    @Published var collapsedSize: CGSize = NotchGeometry.defaultCollapsedSize
    @Published var showsActivity = false
    @Published var expandedHeight: CGFloat = 176
    /// 0…1 — сжатие капсулы вверх при медленном подходе курсора снизу (только home).
    @Published var approachSquish: CGFloat = 0
    @Published var transportAnimationsOn: Bool
    @Published var placement: IslandPlacement
    @Published var along: CGFloat
    @Published var isRelocating = false
    @Published var magnet: IslandPlacement?
    @Published var shakeOffset: CGFloat = 0
    @Published var isEditing = false
    @Published var guideHold: GuideHold = .off
    @Published var modules: Set<IslandModule>
    @Published var earSlots: [IslandModule?]
    @Published private(set) var pulseGeneration = 0

    var isExpanded: Bool { isHovering || isEditing || guideHold == .expanded || guideHold == .editing }

    var dockedPlacement: IslandPlacement {
        if isRelocating {
            return magnet ?? placement
        }
        return placement
    }

    var useOwnerLayout: Bool {
        NotchGeometry.keepsOwnerLayout && placement == .home && !isRelocating
    }

    var hiddenModules: [IslandModule] {
        IslandModule.allCases.filter { !modules.contains($0) }
    }

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.animationsKey)
        transportAnimationsOn = (stored as? Bool) ?? true
        let raw = UserDefaults.standard.string(forKey: Self.placementKey) ?? ""
        placement = IslandPlacement(rawValue: raw) ?? .home
        let storedAlong = UserDefaults.standard.double(forKey: Self.alongKey)
        along = (storedAlong >= 0 && storedAlong <= 1) ? storedAlong : 0.5
        if let saved = UserDefaults.standard.array(forKey: Self.modulesKey) as? [String] {
            let parsed = Set(saved.compactMap(IslandModule.init(rawValue:)))
            modules = parsed.isEmpty && saved.isEmpty ? [] : (parsed.isEmpty ? Set(IslandModule.allCases) : parsed)
        } else {
            modules = Set(IslandModule.allCases)
        }
        earSlots = Self.loadEarSlots()
        if !UserDefaults.standard.bool(forKey: Self.audioOutputAddedKey) {
            modules.insert(.audioOutput)
            UserDefaults.standard.set(true, forKey: Self.audioOutputAddedKey)
            persistModules()
        }
        if !UserDefaults.standard.bool(forKey: Self.micMuteAddedKey) {
            modules.insert(.micMute)
            UserDefaults.standard.set(true, forKey: Self.micMuteAddedKey)
            persistModules()
        }
        if !UserDefaults.standard.bool(forKey: Self.guideAddedKey) {
            modules.insert(.guide)
            UserDefaults.standard.set(true, forKey: Self.guideAddedKey)
            persistModules()
        }
        if !UserDefaults.standard.bool(forKey: Self.scheduleAddedKey) {
            modules.insert(.schedule)
            UserDefaults.standard.set(true, forKey: Self.scheduleAddedKey)
            persistModules()
        }
    }

    func module(atEarSlot index: Int) -> IslandModule? {
        guard earSlots.indices.contains(index) else { return nil }
        guard let module = earSlots[index], modules.contains(module) else { return nil }
        return module
    }

    func cycleEarSlot(at index: Int) {
        guard earSlots.indices.contains(index) else { return }
        let enabled = IslandModule.utilityEarModules.filter { modules.contains($0) }
        guard !enabled.isEmpty else {
            earSlots[index] = nil
            persistEarSlots()
            return
        }
        let current = earSlots[index]
        if let current, enabled.contains(current), let idx = enabled.firstIndex(of: current) {
            let next = idx + 1
            if next >= enabled.count {
                earSlots[index] = nil
            } else {
                assignEarSlot(at: index, module: enabled[next])
            }
        } else {
            assignEarSlot(at: index, module: enabled[0])
        }
        persistEarSlots()
    }

    func assignEarSlot(at index: Int, module: IslandModule?) {
        guard earSlots.indices.contains(index) else { return }
        if let module {
            for i in earSlots.indices where i != index && earSlots[i] == module {
                earSlots[i] = nil
            }
            modules.insert(module)
            earSlots[index] = module
        } else {
            earSlots[index] = nil
        }
        persistModules()
        persistEarSlots()
    }

    private func firstEmptyEarSlot() -> Int? {
        earSlots.firstIndex(where: { $0 == nil })
    }

    private static func loadEarSlots() -> [IslandModule?] {
        guard let raw = UserDefaults.standard.array(forKey: earSlotsKey) as? [String?] else {
            return [.schedule, .clipboard, .micMute]
        }
        let parsed = raw.prefix(3).map { value -> IslandModule? in
            guard let value else { return nil }
            return IslandModule(rawValue: value)
        }
        var slots = Array(parsed)
        while slots.count < 3 {
            slots.append(nil)
        }
        return Array(slots.prefix(3))
    }

    func persistEarSlots() {
        UserDefaults.standard.set(
            earSlots.map { $0?.rawValue },
            forKey: Self.earSlotsKey
        )
    }

    func shows(_ module: IslandModule) -> Bool {
        modules.contains(module)
    }

    func hide(_ module: IslandModule) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.modules.remove(module)
            for index in self.earSlots.indices where self.earSlots[index] == module {
                self.earSlots[index] = nil
            }
            self.persistModules()
            self.persistEarSlots()
        }
    }

    func reveal(_ module: IslandModule) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.modules.insert(module)
            if module.isUtilityEar, !self.earSlots.compactMap({ $0 }).contains(module), let empty = self.firstEmptyEarSlot() {
                self.earSlots[empty] = module
                self.persistEarSlots()
            }
            self.persistModules()
        }
    }

    func beginEditing() {
        guard !isRelocating else { return }
        approachSquish = 0
        isHovering = true
        isEditing = true
    }

    func endEditing() {
        isEditing = false
    }

    func persistPlacement() {
        UserDefaults.standard.set(placement.rawValue, forKey: Self.placementKey)
        UserDefaults.standard.set(along, forKey: Self.alongKey)
    }

    func adoptPlacement(_ placement: IslandPlacement, along: CGFloat) {
        self.placement = placement
        self.along = along
    }

    func persistModules() {
        UserDefaults.standard.set(modules.map(\.rawValue), forKey: Self.modulesKey)
    }

    func goHome() {
        placement = .home
        along = 0.5
        magnet = nil
        isRelocating = false
        persistPlacement()
    }

    func pulse() {
        pulseGeneration += 1
    }

    func toggleTransportAnimations() {
        transportAnimationsOn.toggle()
        UserDefaults.standard.set(transportAnimationsOn, forKey: Self.animationsKey)
    }

    private static let animationsKey = "island.transportAnimations"
    private static let placementKey = "island.placement"
    private static let alongKey = "island.placementAlong"
    private static let modulesKey = "island.modules"
    private static let audioOutputAddedKey = "island.modules.audioOutput.added"
    private static let micMuteAddedKey = "island.modules.micMute.added"
    private static let guideAddedKey = "island.modules.guide.added"
    private static let scheduleAddedKey = "island.modules.schedule.added"
    private static let earSlotsKey = "island.earSlots"
}
