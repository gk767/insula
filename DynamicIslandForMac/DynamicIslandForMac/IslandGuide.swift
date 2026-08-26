import AppKit
import Combine
import SwiftUI

enum GuideHold: Equatable {
    case off
    case collapsed
    case moses
    case expanded
    case editing
}

enum GuideLanguage: String, CaseIterable, Identifiable {
    case ru
    case es
    case en
    case zh
    case ja
    case pt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ru: return "Русский"
        case .es: return "Español"
        case .en: return "English"
        case .zh: return "中文"
        case .ja: return "日本語"
        case .pt: return "Português"
        }
    }

    var skip: String {
        switch self {
        case .ru: return "Пропустить"
        case .es: return "Saltar"
        case .en: return "Skip"
        case .zh: return "跳过"
        case .ja: return "スキップ"
        case .pt: return "Pular"
        }
    }

    var next: String {
        switch self {
        case .ru: return "Дальше"
        case .es: return "Siguiente"
        case .en: return "Next"
        case .zh: return "下一步"
        case .ja: return "次へ"
        case .pt: return "Próximo"
        }
    }

    var done: String {
        switch self {
        case .ru: return "Готово"
        case .es: return "Listo"
        case .en: return "Done"
        case .zh: return "完成"
        case .ja: return "完了"
        case .pt: return "Concluir"
        }
    }
}

enum GuideSpot: Hashable {
    case capsule
    case collapsedMusic
    case collapsedTimer
    case moses
    case appear
    case relocate
    case relocateDock
    case relocateHome
    case timer
    case edit
    case guide
    case mic
    case clipboard
    case media
    case transport
    case audio
    case lyrics
    case playlist
    case progress
    case editTray
    case lyricsPanel
    case lyricsResize
    case lyricsSync
    case playlistPanel
    case end
}

struct GuideCopy {
    let why: String
    let how: String
}

final class IslandGuide: ObservableObject {
    @Published var isActive = false
    @Published var language: GuideLanguage
    @Published var stepIndex = 0
    @Published var frames: [GuideSpot: CGRect] = [:]
    @Published private(set) var steps: [GuideSpot] = []
    @Published var forceLyricsPanel = false

    private weak var state: IslandState?
    private weak var lyrics: LyricsManager?
    private weak var playlist: PlaylistManager?
    private weak var nowPlaying: NowPlayingManager?
    private weak var relocator: IslandRelocator?

    private var openedLyrics = false
    private var openedPlaylist = false
    private var savedPlacement: IslandPlacement?
    private var savedAlong: CGFloat?
    private static let languageKey = "island.guide.language"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.languageKey) ?? ""
        language = GuideLanguage(rawValue: raw) ?? .ru
    }

    var currentSpot: GuideSpot {
        guard steps.indices.contains(stepIndex) else { return .end }
        return steps[stepIndex]
    }

    var isLast: Bool {
        stepIndex >= max(steps.count - 1, 0)
    }

    var copy: GuideCopy {
        GuideCopy.forSpot(currentSpot, language: language)
    }

    var holeScreenRect: CGRect {
        if currentSpot == .end { return .null }
        switch currentSpot {
        case .relocateHome:
            if let screen = NotchGeometry.targetScreen {
                return NotchGeometry.homeButtonFrame(on: screen).insetBy(dx: -8, dy: -8)
            }
        case .relocateDock, .editTray:
            return fallbackHole()
        case .lyricsPanel, .lyricsResize, .lyricsSync:
            if let frame = visibleFrame(where: { $0.contentView is LyricsHost }) {
                return frame.insetBy(dx: -6, dy: -6)
            }
            return frames[.lyricsPanel] ?? .null
        case .playlistPanel:
            if let frame = visibleFrame(where: { $0.contentView is PlaylistHost }) {
                return frame.insetBy(dx: -6, dy: -6)
            }
            return frames[.playlistPanel] ?? .null
        default:
            break
        }

        let pill = geometryPill()
        if let live = frames[currentSpot], live.width > 2, live.height > 2 {
            if isIslandLocal(currentSpot) {
                if pill.width > 2, pill.insetBy(dx: -24, dy: -36).intersects(live) {
                    return paddedHole(live)
                }
            } else {
                return paddedHole(live)
            }
        }
        let fallback = fallbackHole()
        if fallback.width > 2 { return fallback }
        return pill.width > 2 ? paddedHole(pill) : .null
    }

    var islandScreenRect: CGRect {
        let pill = geometryPill()
        if pill.width > 2 { return pill }
        return frames[.capsule] ?? .null
    }

    private func geometryPill() -> CGRect {
        guard let state, let screen = NotchGeometry.targetScreen else { return .null }
        let expanded = state.guideHold == .expanded
            || state.guideHold == .editing
            || state.isExpanded
        return NotchGeometry.pillScreenFrame(
            expanded: expanded,
            activity: true,
            expandedHeight: state.expandedHeight,
            collapsed: state.collapsedSize,
            placement: state.placement,
            along: state.along,
            on: screen
        )
    }

    private func visibleFrame(where match: (NSWindow) -> Bool) -> CGRect? {
        NSApp.windows.first { match($0) && $0.isVisible && $0.alphaValue > 0.05 }?.frame
    }

    private func isIslandLocal(_ spot: GuideSpot) -> Bool {
        switch spot {
        case .lyricsPanel, .lyricsResize, .lyricsSync, .playlistPanel, .relocateHome, .relocateDock, .editTray, .end:
            return false
        default:
            return true
        }
    }

    var showsCursorDemo: Bool {
        currentSpot == .relocate || currentSpot == .relocateDock
    }

    var showsLyricsChrome: Bool {
        forceLyricsPanel
    }

    func bind(
        state: IslandState,
        lyrics: LyricsManager,
        playlist: PlaylistManager,
        nowPlaying: NowPlayingManager,
        relocator: IslandRelocator
    ) {
        self.state = state
        self.lyrics = lyrics
        self.playlist = playlist
        self.nowPlaying = nowPlaying
        self.relocator = relocator
    }

    func setLanguage(_ language: GuideLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    func start() {
        guard let state, !state.isRelocating else { return }
        rebuildSteps()
        guard !steps.isEmpty else { return }
        isActive = true
        stepIndex = 0
        applyCurrent()
    }

    func stop() {
        isActive = false
        stepIndex = 0
        teardownDemo()
        restoreIslandPlace()
        state?.guideHold = .off
        forceLyricsPanel = false
        frames.removeAll()
    }

    func next() {
        guard isActive else { return }
        if isLast {
            stop()
            return
        }
        stepIndex += 1
        applyCurrent()
    }

    func skip() {
        stop()
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    func setFrame(_ spot: GuideSpot, _ rect: CGRect?) {
        DispatchQueue.main.async { [weak self] in
            self?.applyFrame(spot, rect)
        }
    }

    private func applyFrame(_ spot: GuideSpot, _ rect: CGRect?) {
        var next = frames
        if let rect, rect.width > 2, rect.height > 2,
           rect.origin.x.isFinite, rect.origin.y.isFinite,
           rect.width.isFinite, rect.height.isFinite {
            let rounded = CGRect(
                x: rect.origin.x.rounded(),
                y: rect.origin.y.rounded(),
                width: rect.width.rounded(),
                height: rect.height.rounded()
            )
            next[spot] = rounded
            if spot == .capsule {
                next[.moses] = rounded
                next[.appear] = rounded
                next[.relocate] = rounded
                next[.relocateDock] = rounded
            }
        } else {
            next.removeValue(forKey: spot)
        }
        if next != frames {
            frames = next
        }
    }

    private func paddedHole(_ rect: CGRect) -> CGRect {
        let pad: CGFloat = min(6, max(3, min(rect.width, rect.height) * 0.18))
        return rect.insetBy(dx: -pad, dy: -pad)
    }

    func rebuildSteps() {
        guard let state else {
            steps = []
            return
        }
        var next: [GuideSpot] = [.capsule, .collapsedMusic]
        if state.shows(.timer) {
            next.append(.collapsedTimer)
        }
        next.append(.moses)
        next.append(.appear)
        next.append(.relocate)
        next.append(.relocateDock)
        next.append(.relocateHome)
        if state.shows(.timer) {
            next.append(.timer)
        }
        next.append(.edit)
        if state.shows(.guide) {
            next.append(.guide)
        }
        if state.shows(.micMute) {
            next.append(.mic)
        }
        if state.shows(.clipboard) {
            next.append(.clipboard)
        }
        next.append(.media)
        next.append(.transport)
        if state.shows(.audioOutput) {
            next.append(.audio)
        }
        if state.shows(.lyrics) {
            next.append(.lyrics)
        }
        if state.shows(.playlist), playlist?.available == true {
            next.append(.playlist)
        }
        if (nowPlaying?.duration ?? 0) > 1 {
            next.append(.progress)
        }
        next.append(.editTray)
        if state.shows(.lyrics) {
            next.append(.lyricsPanel)
            next.append(.lyricsResize)
            next.append(.lyricsSync)
        }
        if state.shows(.playlist), playlist?.available == true {
            next.append(.playlistPanel)
        }
        next.append(.end)
        steps = next
        if stepIndex >= steps.count {
            stepIndex = max(steps.count - 1, 0)
        }
    }

    private func applyCurrent() {
        rebuildSteps()
        guard let state else { return }
        let spot = currentSpot
        switch spot {
        case .capsule, .collapsedMusic, .collapsedTimer, .appear, .relocate:
            closePanelsIfOpened()
            restoreIslandPlace()
            state.endEditing()
            forceLyricsPanel = false
            state.guideHold = .collapsed
        case .relocateDock, .relocateHome:
            closePanelsIfOpened()
            state.endEditing()
            forceLyricsPanel = false
            demoDockBottom()
            state.guideHold = .collapsed
        case .moses:
            closePanelsIfOpened()
            restoreIslandPlace()
            state.endEditing()
            forceLyricsPanel = false
            state.guideHold = state.placement == .home ? .moses : .collapsed
        case .editTray:
            closePanelsIfOpened()
            restoreIslandPlace()
            forceLyricsPanel = false
            state.guideHold = .editing
            state.beginEditing()
        case .lyricsPanel, .lyricsResize, .lyricsSync:
            restoreIslandPlace()
            state.endEditing()
            state.guideHold = .expanded
            playlist?.isOpen = false
            lyrics?.setPanelSize(LyricsManager.defaultPanelSize)
            forceLyricsPanel = true
            if lyrics?.isOpen == false {
                lyrics?.isOpen = true
                openedLyrics = true
            }
        case .playlistPanel:
            restoreIslandPlace()
            state.endEditing()
            state.guideHold = .expanded
            forceLyricsPanel = false
            if openedLyrics {
                lyrics?.isOpen = false
                openedLyrics = false
            }
            if playlist?.available == true, playlist?.isOpen == false {
                playlist?.isOpen = true
                openedPlaylist = true
            }
        case .end:
            closePanelsIfOpened()
            restoreIslandPlace()
            state.endEditing()
            forceLyricsPanel = false
            state.guideHold = .expanded
        default:
            closePanelsIfOpened()
            restoreIslandPlace()
            state.endEditing()
            forceLyricsPanel = false
            state.guideHold = .expanded
        }
        relocator?.updateHomeWindow()
    }

    private func demoDockBottom() {
        guard let state else { return }
        if savedPlacement == nil {
            savedPlacement = state.placement
            savedAlong = state.along
        }
        state.adoptPlacement(.bottom, along: 0.5)
    }

    private func restoreIslandPlace() {
        guard let state, let saved = savedPlacement else { return }
        state.adoptPlacement(saved, along: savedAlong ?? 0.5)
        savedPlacement = nil
        savedAlong = nil
        relocator?.updateHomeWindow()
    }

    private func closePanelsIfOpened() {
        if openedLyrics {
            lyrics?.isOpen = false
            openedLyrics = false
        }
        if openedPlaylist {
            playlist?.isOpen = false
            openedPlaylist = false
        }
    }

    private func teardownDemo() {
        closePanelsIfOpened()
        forceLyricsPanel = false
        state?.endEditing()
    }

    private func fallbackHole() -> CGRect {
        guard let state, let screen = NotchGeometry.targetScreen else { return .null }
        switch currentSpot {
        case .capsule, .moses, .appear, .relocate:
            return NotchGeometry.pillScreenFrame(
                expanded: false,
                activity: true,
                expandedHeight: state.expandedHeight,
                collapsed: state.collapsedSize,
                placement: state.placement,
                along: state.along,
                on: screen
            ).insetBy(dx: -4, dy: -4)
        case .relocateDock:
            return NotchGeometry.pillScreenFrame(
                expanded: false,
                activity: true,
                expandedHeight: state.expandedHeight,
                collapsed: state.collapsedSize,
                placement: .bottom,
                along: 0.5,
                on: screen
            ).insetBy(dx: -4, dy: -4)
        case .editTray:
            let chrome = NotchGeometry.editChromeScreenFrame(
                expanded: true,
                activity: true,
                expandedHeight: state.expandedHeight,
                collapsed: state.collapsedSize,
                placement: state.placement,
                along: state.along,
                editing: true,
                on: screen
            )
            return chrome.isNull ? .null : chrome.insetBy(dx: -4, dy: -4)
        case .lyricsPanel, .lyricsResize, .lyricsSync:
            return frames[.lyricsPanel] ?? .null
        case .playlistPanel:
            return frames[.playlistPanel] ?? .null
        default:
            return .null
        }
    }

    static func screenRect(fromSwiftGlobal rect: CGRect, in window: NSWindow) -> CGRect {
        let height = window.contentView?.bounds.height ?? window.frame.height
        let flipped = NSRect(
            x: rect.minX,
            y: height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        return window.convertToScreen(flipped)
    }
}

private struct IslandGuideKey: EnvironmentKey {
    static let defaultValue: IslandGuide? = nil
}

extension EnvironmentValues {
    var islandGuide: IslandGuide? {
        get { self[IslandGuideKey.self] }
        set { self[IslandGuideKey.self] = newValue }
    }
}

extension View {
    func guideTarget(_ spot: GuideSpot) -> some View {
        background {
            GuideAnchorProbe(spot: spot)
                .allowsHitTesting(false)
        }
    }

    func reportGuideFrame(_ spot: GuideSpot, guide _: IslandGuide, window _: NSWindow?) -> some View {
        guideTarget(spot)
    }
}

private struct GuideAnchorProbe: View {
    var spot: GuideSpot
    @Environment(\.islandGuide) private var guide

    var body: some View {
        GuideAnchorView(spot: spot, guide: guide)
    }
}

private struct GuideAnchorView: NSViewRepresentable {
    var spot: GuideSpot
    var guide: IslandGuide?

    func makeNSView(context: Context) -> GuideAnchorNSView {
        let view = GuideAnchorNSView()
        view.spot = spot
        view.guide = guide
        return view
    }

    func updateNSView(_ nsView: GuideAnchorNSView, context: Context) {
        nsView.spot = spot
        nsView.guide = guide
        nsView.report()
    }
}

final class GuideAnchorNSView: NSView {
    var spot: GuideSpot = .capsule
    weak var guide: IslandGuide?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        DispatchQueue.main.async { [weak self] in
            self?.report()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.window == nil {
                self.guide?.setFrame(self.spot, nil)
            } else {
                self.report()
            }
        }
    }

    func report() {
        guard let window, let guide, let content = window.contentView else { return }
        guard bounds.width > 1, bounds.height > 1 else { return }
        let local = convert(bounds, to: content)
        guard local.width > 1, local.height > 1 else { return }

        let fromTop = CGRect(
            x: window.frame.minX + local.minX,
            y: window.frame.maxY - local.maxY,
            width: local.width,
            height: local.height
        )
        let fromBottom = CGRect(
            x: window.frame.minX + local.minX,
            y: window.frame.minY + local.minY,
            width: local.width,
            height: local.height
        )
        let preferTop = abs(fromTop.midY - window.frame.maxY) <= abs(fromBottom.midY - window.frame.maxY)
        let screen = preferTop ? fromTop : fromBottom
        guard screen.width > 2 else { return }
        guide.setFrame(spot, screen)
    }
}

extension GuideCopy {
    static func forSpot(_ spot: GuideSpot, language: GuideLanguage) -> GuideCopy {
        switch language {
        case .ru: return ru(spot)
        case .es: return es(spot)
        case .en: return en(spot)
        case .zh: return zh(spot)
        case .ja: return ja(spot)
        case .pt: return pt(spot)
        }
    }

    private static func ru(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "В свёрнутом видно, что остров живой — не надо сразу его раскрывать.",
                how: "Капелька сидит у выреза. На ней то, что сейчас есть: музыка, таймер."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Сразу видно, играет ли что-то, без большого острова.",
                how: "Слева на капельке — название и прогресс, если трек идёт."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "Таймер не прячется, пока остров маленький.",
                how: "Справа на капельке — время. Раскройте остров, чтобы поставить новый."
            )
        case .moses:
            return GuideCopy(
                why: "Капелька лежит поверх меню и адресной строки. Глухое стекло закрывает клики; если её спрятать — пропадёт островок.",
                how: "Медленно к острову — в стекле щель, широкий овал за курсором по нижней кромке, клики проходят. Быстро наехал — щели нет."
            )
        case .appear:
            return GuideCopy(
                why: "Иначе кажется, что остров сам вылезает от любого движения у чёлки, а когда его зовут — тормозит.",
                how: "Проскочил мимо за доли секунды — большой не открывается. Задержись на острове около 0.1 с. Медленно — сначала щель, большой в верхней трети у камеры."
            )
        case .relocate:
            return GuideCopy(
                why: "Иногда удобнее снизу или сбоку, не у камеры.",
                how: "Три быстрых клика по острову за полторы секунды — он едет за курсором."
            )
        case .relocateDock:
            return GuideCopy(
                why: "У края островок не висит посередине стола — он прилипает к стене.",
                how: "Кликни — остров едет по прямой к ближайшей стене. Снизу пилюля, сбоку карточка."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Вернуться к камере сразу, без поездки по экрану.",
                how: "Домик у выреза. Клик — сразу домой."
            )
        case .timer:
            return GuideCopy(
                why: "Отсчёт ставят здесь, не в часах и не в отдельном приложении.",
                how: "Левое ухо: часы, минуты, секунды. По окончании — звук и уведомление, музыка на паузе, потом снова играет."
            )
        case .edit:
            return GuideCopy(
                why: "Не всем нужны все кнопки. Лишнее не держать на пилюле.",
                how: "Карандаш в правом ухе, у выреза. Тап — режим правки. Ещё раз или «Готово» — выход."
            )
        case .guide:
            return GuideCopy(
                why: "Этот тур можно открыть снова, если что-то забылось.",
                how: "Кнопка рядом с карандашом. Тап — с начала. Во время тура тот же тап закрывает его."
            )
        case .mic:
            return GuideCopy(
                why: "В Zoom и Discord у каждого своя кнопка mute — легко забыть, где она.",
                how: "Тап глушит вход Mac для всех приложений. Белый микрофон — вас слышно. Красный на белом — нет."
            )
        case .clipboard:
            return GuideCopy(
                why: "Последние скопированные тексты не теряются сразу.",
                how: "Иконка буфера в правом ухе. Тап — список, ещё тап по строке — копирует снова."
            )
        case .media:
            return GuideCopy(
                why: "Обложка и название — чтобы понять, что сейчас играет.",
                how: "Картинка и строка под вырезом. Тап по обложке открывает плеер."
            )
        case .transport:
            return GuideCopy(
                why: "Управление треком — на большом острове, не на капельке.",
                how: "Назад, пауза, дальше. Если анимации включены в редакте — пауза и перемотка подсвечиваются."
            )
        case .audio:
            return GuideCopy(
                why: "Музыка уже на острове, а наушники снимаешь на звонок или наоборот.",
                how: "Капсула после транспорта. Кружок только если устройство есть: колонки, наушники, MacBook, машина. Активный — белый."
            )
        case .lyrics:
            return GuideCopy(
                why: "Текст песни в остров не влезает, его смотрят рядом.",
                how: "Пузырёк рядом с транспортом. Если текста нет — кнопки нет или она неактивна."
            )
        case .playlist:
            return GuideCopy(
                why: "С островка виден один трек, а дальше в очереди — нет.",
                how: "Кнопка списка — только если Music отдал текущий плейлист. Тап открывает окно, текущий трек выделен."
            )
        case .progress:
            return GuideCopy(
                why: "Сколько прошло и сколько осталось — без окна плеера.",
                how: "Полоса внизу большого острова. Её можно перетаскивать, чтобы перемотать."
            )
        case .editTray:
            return GuideCopy(
                why: "Снятые кнопки не пропадают — они ждут в лотке под островом.",
                how: "Тап по кнопке на острове — в лоток. Тап по фишке в лотке — обратно. Искра включает анимацию паузы и перемотки. «Готово» закрывает правку."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "Текст читают рядом с островом, не внутри капельки.",
                how: "Панель стеклянная, с крестиком. Её можно подвинуть. Музыка при этом играет."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Кому-то окно мелкое, кому-то строки рано или поздно — единого размера нет.",
                how: "Потяните белый кружок в углу — окно меняет размер."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Строки иногда идут раньше или позже музыки.",
                how: "Минус — позже, плюс — раньше. Сдвиг помнится на эту песню."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "Очередь целиком, не только текущий трек.",
                how: "Имя плейлиста сверху, текущий выделен. Тап по строке — играет этот трек."
            )
        case .end:
            return GuideCopy(
                why: "Тур можно закрыть и пользоваться островом.",
                how: "Приятного использования. Кнопка гайда откроет его снова."
            )
        }
    }

    private static func es(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "En pequeño se ve que la isla está viva: no hace falta abrirla enseguida.",
                how: "La pastilla está en el recorte. Ahí aparecen la música y el temporizador, si los hay."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Se ve al momento si suena algo, sin abrir la isla.",
                how: "A la izquierda: el título y el progreso si hay un tema."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "El temporizador no se esconde cuando la isla está pequeña.",
                how: "A la derecha: el tiempo. Abre la isla para poner uno nuevo."
            )
        case .moses:
            return GuideCopy(
                why: "La pastilla cubre el menú y la barra de direcciones. Si es opaca, no puedes pulsar lo de debajo; si la ocultas, desaparece la isla.",
                how: "Al acercarte despacio aparece una hendidura ovalada que sigue el cursor por el borde inferior y deja pasar los clics. Si llegas rápido, no hay hendidura."
            )
        case .appear:
            return GuideCopy(
                why: "Si no, parece que la isla se abre sola con cualquier movimiento junto al recorte, y que tarda cuando la llamas de verdad.",
                how: "Si solo pasas de largo, no se abre. Quédate unos 0,1 s. Despacio: primero la hendidura; grande solo en el tercio superior, junto a la cámara."
            )
        case .relocate:
            return GuideCopy(
                why: "A veces viene mejor abajo o a un lado, no junto a la cámara.",
                how: "Tres clics rápidos en la isla en un segundo y medio: viaja con el cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "En el borde no queda en medio del escritorio: se pega a la pared.",
                how: "Haz clic: va en línea recta a la pared más cercana. Abajo pastilla; al lado, tarjeta."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Volver a la cámara al instante, sin cruzar la pantalla.",
                how: "La casita está en el recorte. Un clic — a casa."
            )
        case .timer:
            return GuideCopy(
                why: "La cuenta atrás se pone aquí, no en Reloj ni en otra app.",
                how: "Oreja izquierda: horas, minutos, segundos. Al terminar: sonido, aviso, la música se pausa y luego sigue."
            )
        case .edit:
            return GuideCopy(
                why: "No todo el mundo necesita todos los botones. Lo de más no tiene que estar en la pastilla.",
                how: "El lápiz está en la oreja derecha, junto al recorte. Un toque entra en edición. Otro toque o «Listo» sale."
            )
        case .guide:
            return GuideCopy(
                why: "Este recorrido se puede abrir otra vez si se olvida algo.",
                how: "El botón está junto al lápiz. Un toque empieza de cero. Durante el tour, el mismo toque lo cierra."
            )
        case .mic:
            return GuideCopy(
                why: "En Zoom y Discord cada uno tiene su silencio: es fácil olvidar cuál está activo.",
                how: "Un toque silencia la entrada del Mac para todas las apps. Micrófono blanco: te oyen. Rojo sobre blanco: no."
            )
        case .clipboard:
            return GuideCopy(
                why: "Los últimos textos copiados no se pierden enseguida.",
                how: "El icono está en la oreja derecha. Un toque abre la lista; otro en una línea la vuelve a copiar."
            )
        case .media:
            return GuideCopy(
                why: "La carátula y el título dicen qué está sonando.",
                how: "Debajo del recorte. Un toque en la carátula abre el reproductor."
            )
        case .transport:
            return GuideCopy(
                why: "El tema se controla en la isla grande, no en la pastilla.",
                how: "Atrás, pausa, adelante. Si las animaciones están on en edición, pausa y salto se marcan."
            )
        case .audio:
            return GuideCopy(
                why: "La música ya está en la isla; a veces pasas de auriculares a altavoz.",
                how: "La cápsula va detrás del transporte. Un círculo solo si el aparato existe: altavoz, auriculares, MacBook, coche. El activo es blanco."
            )
        case .lyrics:
            return GuideCopy(
                why: "La letra no cabe en la isla; se lee al lado.",
                how: "El bocadillo está junto al transporte. Si no hay letra, el botón no aparece o no responde."
            )
        case .playlist:
            return GuideCopy(
                why: "En la isla se ve un tema; no se ve lo que sigue.",
                how: "El botón de lista sale solo si Music entrega la lista actual. Un toque abre la ventana; el tema actual está marcado."
            )
        case .progress:
            return GuideCopy(
                why: "Cuánto ha pasado y cuánto queda, sin abrir el reproductor.",
                how: "La barra está abajo. Arrástrala para saltar en el tema."
            )
        case .editTray:
            return GuideCopy(
                why: "Los botones quitados no se pierden: esperan en la bandeja bajo la isla.",
                how: "Toque en la isla: van a la bandeja. Toque en la ficha: vuelven. La chispa enciende la animación de pausa y salto. «Listo» cierra la edición."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "La letra se lee al lado de la isla, no dentro de la pastilla.",
                how: "El panel es de cristal, con una cruz. Se puede mover. La música sigue."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "A unos les va una ventana chica; a otros las líneas van pronto o tarde.",
                how: "Tira del círculo blanco de la esquina para cambiar el tamaño."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "A veces las líneas van antes o después que la música.",
                how: "Menos: más tarde. Más: más pronto. El desfase se guarda para esta canción."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "Toda la cola, no solo el tema actual.",
                how: "El nombre va arriba, el actual está marcado. Un toque en una línea la reproduce."
            )
        case .end:
            return GuideCopy(
                why: "Puedes cerrar el recorrido y usar la isla.",
                how: "Que lo disfrutes. El botón de la guía lo abre otra vez."
            )
        }
    }

    private static func en(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "Collapsed, you can see the island is alive — you don’t have to open it right away.",
                how: "The capsule sits at the notch. Music and the timer show on it when they’re there."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "You can tell if something is playing without opening the island.",
                how: "On the left of the capsule: title and progress while a track is on."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "The timer stays visible while the island is small.",
                how: "On the right of the capsule: the time. Open the island to set a new one."
            )
        case .moses:
            return GuideCopy(
                why: "The capsule sits over the menu and the address bar. If it’s solid you can’t click what’s under it; if you hide it, the island is gone.",
                how: "Approach slowly — a wide oval gap follows the cursor along the bottom edge, and clicks pass through. Arrive fast — no gap."
            )
        case .appear:
            return GuideCopy(
                why: "Otherwise it feels like the island pops open from any move near the notch, and lags when you actually want it.",
                how: "A quick pass-through does not open it. Stay about 0.1 s. Approach slowly — gap first; large only in the top third, by the camera."
            )
        case .relocate:
            return GuideCopy(
                why: "Sometimes it’s better at the bottom or the side, not by the camera.",
                how: "Three quick clicks on the island within a second and a half — it follows the cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "At an edge it doesn’t sit in the middle of the desk — it sticks to the wall.",
                how: "Click — it travels in a straight line to the nearest wall. Bottom is a pill; the side is a card."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Get back to the camera at once, without riding across the screen.",
                how: "The house sits at the notch. Click — you’re home."
            )
        case .timer:
            return GuideCopy(
                why: "Countdowns belong here, not in Clock or another app.",
                how: "Left ear: hours, minutes, seconds. When it ends: sound, a notification, music pauses, then it plays again."
            )
        case .edit:
            return GuideCopy(
                why: "Not everyone needs every button. Keep extras off the pill.",
                how: "The pencil is in the right ear, by the notch. Tap to edit. Tap again or Done to leave."
            )
        case .guide:
            return GuideCopy(
                why: "You can run this tour again if something slips your mind.",
                how: "The button sits next to the pencil. Tap to start from the beginning. During the tour, the same tap closes it."
            )
        case .mic:
            return GuideCopy(
                why: "Zoom and Discord each have their own mute — easy to forget which one is on.",
                how: "Tap mutes the Mac input for every app. White mic: they hear you. Red on white: they don’t."
            )
        case .clipboard:
            return GuideCopy(
                why: "Recent copied text doesn’t vanish at once.",
                how: "The clipboard icon is in the right ear. Tap for the list; tap a row to copy it again."
            )
        case .media:
            return GuideCopy(
                why: "Artwork and title show what’s playing.",
                how: "Under the notch. Tap the artwork to open the player."
            )
        case .transport:
            return GuideCopy(
                why: "Track control lives on the large island, not the capsule.",
                how: "Back, pause, next. If animations are on in edit, pause and skip light up."
            )
        case .audio:
            return GuideCopy(
                why: "Music is already on the island; you still switch from headphones to speakers.",
                how: "The capsule sits after transport. A circle only if that device exists: speakers, headphones, MacBook, car. The active one is white."
            )
        case .lyrics:
            return GuideCopy(
                why: "Lyrics don’t fit in the island; you read them beside it.",
                how: "The bubble is next to transport. If there’s no text, the button is missing or inactive."
            )
        case .playlist:
            return GuideCopy(
                why: "The island shows one track, not what’s next.",
                how: "The list button appears only if Music gives the current playlist. Tap opens the window; the current track is highlighted."
            )
        case .progress:
            return GuideCopy(
                why: "Elapsed and remaining time without opening the player.",
                how: "The bar is at the bottom of the large island. Drag it to scrub."
            )
        case .editTray:
            return GuideCopy(
                why: "Removed buttons aren’t lost — they wait in the tray under the island.",
                how: "Tap a button on the island to send it to the tray. Tap a chip to bring it back. The sparkle turns pause and skip animation on. Done leaves edit."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "You read lyrics beside the island, not inside the capsule.",
                how: "The panel is glass, with a close button. You can move it. Music keeps playing."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Some want a small window; some need lines earlier or later — there’s no one size.",
                how: "Drag the white circle in the corner to resize."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Lines sometimes run ahead of the music, or behind it.",
                how: "Minus — later. Plus — earlier. The offset is remembered for this song."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "The whole queue, not just the current track.",
                how: "The playlist name is at the top; the current track is highlighted. Tap a row to play it."
            )
        case .end:
            return GuideCopy(
                why: "You can close the tour and use the island.",
                how: "Enjoy it. The guide button opens this again."
            )
        }
    }

    private static func zh(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "收起时也能看出岛是活的，不必马上展开。",
                how: "胶囊贴在刘海处。有音乐或计时器时，会显示在上面。"
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "不用展开也能知道现在有没有在播。",
                how: "胶囊左侧是歌名和进度。"
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "岛很小的时候，计时器仍然看得见。",
                how: "胶囊右侧是时间。要设新的，先展开岛。"
            )
        case .moses:
            return GuideCopy(
                why: "胶囊盖在菜单和地址栏上。如果完全挡住，点不到下面；如果藏起来，岛就没了。",
                how: "慢慢靠近会出现一条宽椭圆缝，跟着光标沿下沿移动，点击可以穿过。冲得很快则没有缝。"
            )
        case .appear:
            return GuideCopy(
                why: "否则会觉得在刘海附近一动就会自己展开，真要用时又很慢。",
                how: "只是快速穿过不会展开。在岛上停大约 0.1 秒。慢慢靠近：先有缝，只有到摄像头旁上三分之一才变大。"
            )
        case .relocate:
            return GuideCopy(
                why: "有时放在下方或两侧更方便，不必贴着摄像头。",
                how: "在一秒半内连点岛三次，它就会跟着光标走。"
            )
        case .relocateDock:
            return GuideCopy(
                why: "靠边缘时它不会停在桌面中间，而是贴到墙上。",
                how: "点一下，小岛沿直线飞向最近的墙。下方是胶囊，侧面是卡片。"
            )
        case .relocateHome:
            return GuideCopy(
                why: "要马上回到摄像头，不用在屏幕上走一圈。",
                how: "小屋在刘海旁。点一下就回家。"
            )
        case .timer:
            return GuideCopy(
                why: "倒计时就在这里设，不用打开时钟或其他应用。",
                how: "左耳：时、分、秒。结束时会响、会通知，音乐会先暂停再继续。"
            )
        case .edit:
            return GuideCopy(
                why: "不是每个人都需要全部按钮，多余的不必留在胶囊上。",
                how: "铅笔在右耳、靠刘海。点一下进入编辑，再点或「完成」退出。"
            )
        case .guide:
            return GuideCopy(
                why: "忘了可以再看一遍。",
                how: "按钮在铅笔旁边。点一下从头开始。导览中再点同一按钮会关掉。"
            )
        case .mic:
            return GuideCopy(
                why: "Zoom、Discord 各自有静音，很容易搞混。",
                how: "点一下会关掉 Mac 的输入，对所有应用生效。白色麦克风表示听得见你；白底红标表示听不见。"
            )
        case .clipboard:
            return GuideCopy(
                why: "刚复制的文字不会马上丢掉。",
                how: "剪贴板图标在右耳。点开列表，再点一行会重新复制。"
            )
        case .media:
            return GuideCopy(
                why: "封面和歌名告诉你现在在播什么。",
                how: "在刘海下面。点封面会打开播放器。"
            )
        case .transport:
            return GuideCopy(
                why: "切歌在大岛上，不在小胶囊上。",
                how: "上一首、暂停、下一首。若在编辑里打开了动画，暂停和跳转会有提示。"
            )
        case .audio:
            return GuideCopy(
                why: "音乐已经在岛上，有时要在耳机和扬声器之间切换。",
                how: "胶囊在播放键后面。只有真正连上的设备才有圆点：音箱、耳机、MacBook、车机。当前是白色。"
            )
        case .lyrics:
            return GuideCopy(
                why: "歌词塞不进岛里，要在旁边看。",
                how: "气泡在播放键旁边。没有歌词时按钮会消失或不可用。"
            )
        case .playlist:
            return GuideCopy(
                why: "岛上只能看到当前这一首，看不到后面排队的。",
                how: "只有 Music 给出当前播放列表时才有列表按钮。点开窗口，当前曲目会高亮。"
            )
        case .progress:
            return GuideCopy(
                why: "不用打开播放器也能看到已播和剩余时间。",
                how: "进度条在大岛底部，拖动可以跳转。"
            )
        case .editTray:
            return GuideCopy(
                why: "拿掉的按钮不会丢，它们在岛下面的托盘里。",
                how: "点岛上的按钮会放进托盘；点托盘里的芯片会放回。火花开关控制暂停和跳转动画。「完成」退出编辑。"
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "歌词在岛旁边读，不塞进胶囊。",
                how: "玻璃面板，有关闭按钮，可以挪动。音乐继续播放。"
            )
        case .lyricsResize:
            return GuideCopy(
                why: "有人要小窗，有人觉得歌词偏早或偏晚，没有统一尺寸。",
                how: "拖动角落的白圆点改变大小。"
            )
        case .lyricsSync:
            return GuideCopy(
                why: "歌词有时会比音乐早或晚。",
                how: "减号更晚，加号更早。偏移会记住，只对这首歌。"
            )
        case .playlistPanel:
            return GuideCopy(
                why: "整条队列，不只是当前这一首。",
                how: "列表名在顶部，当前曲目高亮。点一行就会播放。"
            )
        case .end:
            return GuideCopy(
                why: "可以关掉导览，开始用岛。",
                how: "祝使用愉快。指南按钮可以再打开。"
            )
        }
    }

    private static func ja(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "畳んだままでも島が生きているのが分かります。すぐ開かなくて大丈夫です。",
                how: "カプセルはノッチにあります。音楽やタイマーがあれば、その上に出ます。"
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "島を開かなくても、何か再生中か分かります。",
                how: "カプセルの左：曲名と、再生中なら進捗。"
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "島が小さくてもタイマーは見えます。",
                how: "カプセルの右：残り時間。新しくセットするときは島を開きます。"
            )
        case .moses:
            return GuideCopy(
                why: "カプセルはメニューやアドレスバーの上にあります。完全に塞ぐと下がクリックできず、隠すと島がなくなります。",
                how: "ゆっくり近づくと、下辺に沿ってカーソルを追う幅広の楕円の隙間ができ、クリックが通ります。速く乗ると隙間はありません。"
            )
        case .appear:
            return GuideCopy(
                why: "そうしないと、ノッチ付近の動きだけで島が開き、本当に呼びたいときは遅いように感じます。",
                how: "素早く通りすぎるだけでは開きません。約 0.1 秒止まってください。ゆっくり — 先に隙間、大きいのはカメラ横の上三分の一だけ。"
            )
        case .relocate:
            return GuideCopy(
                why: "カメラのそばより、下や横のほうが楽なことがあります。",
                how: "1.5秒以内に島を3回クリックすると、カーソルに付いて動きます。"
            )
        case .relocateDock:
            return GuideCopy(
                why: "端では机の真ん中に浮かず、壁に付きます。",
                how: "クリックすると、いちばん近い壁まで直線で移動します。下はピル、横はカード。"
            )
        case .relocateHome:
            return GuideCopy(
                why: "画面を横断せず、すぐカメラへ戻ります。",
                how: "家のマークはノッチにあります。クリックですぐホーム。"
            )
        case .timer:
            return GuideCopy(
                why: "カウントダウンはここで、時計アプリではありません。",
                how: "左耳：時・分・秒。終了時は音と通知、音楽は一時停止してから再開します。"
            )
        case .edit:
            return GuideCopy(
                why: "すべてのボタンが必要な人ばかりではありません。余分はピルに置かないでください。",
                how: "鉛筆は右耳、ノッチ側。タップで編集。もう一度か「完了」で終了。"
            )
        case .guide:
            return GuideCopy(
                why: "忘れたら、このツアーをやり直せます。",
                how: "ボタンは鉛筆の隣。タップで最初から。ツアー中の同じタップで閉じます。"
            )
        case .mic:
            return GuideCopy(
                why: "Zoom と Discord はそれぞれミュートがあり、どれがオンか忘れやすいです。",
                how: "タップで Mac の入力を全アプリ分ミュート。白いマイクは聞こえる。白地に赤は聞こえない。"
            )
        case .clipboard:
            return GuideCopy(
                why: "コピーしたテキストはすぐ消えません。",
                how: "クリップボードは右耳。タップで一覧、行をタップでもう一度コピー。"
            )
        case .media:
            return GuideCopy(
                why: "ジャケットと曲名で、今何が流れているか分かります。",
                how: "ノッチの下。ジャケットをタップするとプレーヤーが開きます。"
            )
        case .transport:
            return GuideCopy(
                why: "曲の操作は大きい島にあり、カプセルにはありません。",
                how: "戻る、一時停止、次へ。編集でアニメがオンなら、一時停止とスキップが光ります。"
            )
        case .audio:
            return GuideCopy(
                why: "音楽はすでに島にあります。それでもヘッドホンとスピーカーを切り替えます。",
                how: "カプセルは操作の後ろ。機器があるときだけ丸：スピーカー、ヘッドホン、MacBook、車。使っているのは白。"
            )
        case .lyrics:
            return GuideCopy(
                why: "歌詞は島に入りきらないので、横で読みます。",
                how: "吹き出しは操作の隣。歌詞がなければボタンはないか、押せません。"
            )
        case .playlist:
            return GuideCopy(
                why: "島には今の1曲だけで、次は見えません。",
                how: "リストボタンは Music が再生中プレイリストを渡したときだけ。タップで窓、再生中は強調。"
            )
        case .progress:
            return GuideCopy(
                why: "プレーヤーを開かなくても経過と残りが分かります。",
                how: "バーは大きい島の下。ドラッグでシーク。"
            )
        case .editTray:
            return GuideCopy(
                why: "外したボタンは消えません。島の下のトレイで待ちます。",
                how: "島のボタンをタップしてトレイへ。チップをタップして戻す。キラキラで一時停止とスキップのアニメ。「完了」で編集終了。"
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "歌詞は島の横で読み、カプセルの中ではありません。",
                how: "ガラスのパネル、閉じるボタンあり。動かせます。音楽は止まりません。"
            )
        case .lyricsResize:
            return GuideCopy(
                why: "小さい窓がいい人も、行が早い・遅い人もいて、一つの大きさはありません。",
                how: "角の白い丸をドラッグしてサイズを変えます。"
            )
        case .lyricsSync:
            return GuideCopy(
                why: "行が音楽より先、または遅れていることがあります。",
                how: "マイナスは遅く、プラスは早く。ずれはこの曲だけ覚えます。"
            )
        case .playlistPanel:
            return GuideCopy(
                why: "今の1曲だけでなく、キュー全体です。",
                how: "上にプレイリスト名、再生中は強調。行をタップして再生。"
            )
        case .end:
            return GuideCopy(
                why: "ツアーを閉じて島を使えます。",
                how: "どうぞご利用ください。ガイドボタンでもう一度開けます。"
            )
        }
    }

    private static func pt(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "Fechada, dá para ver que a ilha está viva — não precisa abrir na hora.",
                how: "A cápsula fica no recorte. Música e temporizador aparecem nela quando existem."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Dá para saber se algo está tocando sem abrir a ilha.",
                how: "À esquerda da cápsula: título e progresso enquanto a faixa toca."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "O temporizador continua visível com a ilha pequena.",
                how: "À direita da cápsula: o tempo. Abra a ilha para definir um novo."
            )
        case .moses:
            return GuideCopy(
                why: "A cápsula cobre o menu e a barra de endereço. Se for sólida, não dá para clicar o que está embaixo; se esconder, a ilha some.",
                how: "Chegue devagar — uma fenda oval larga segue o cursor na borda de baixo, e os cliques passam. Chegue rápido — sem fenda."
            )
        case .appear:
            return GuideCopy(
                why: "Senão parece que a ilha abre sozinha com qualquer movimento perto do recorte, e demora quando você realmente quer.",
                how: "Passar depressa não abre. Fique uns 0,1 s. Chegue devagar — primeiro a fenda; grande só no terço de cima, junto à câmera."
            )
        case .relocate:
            return GuideCopy(
                why: "Às vezes fica melhor embaixo ou do lado, não na câmera.",
                how: "Três cliques rápidos na ilha em um segundo e meio — ela segue o cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "Na borda ela não fica no meio da mesa — cola na parede.",
                how: "Clique: vai em linha reta até a parede mais perto. Embaixo é pílula; do lado, cartão."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Voltar à câmera na hora, sem atravessar a tela.",
                how: "A casinha fica no recorte. Um clique — você está em casa."
            )
        case .timer:
            return GuideCopy(
                why: "A contagem fica aqui, não no Relógio nem em outro app.",
                how: "Orelha esquerda: horas, minutos, segundos. Ao terminar: som, notificação, a música pausa e depois volta."
            )
        case .edit:
            return GuideCopy(
                why: "Nem todo mundo precisa de todos os botões. O que sobra não precisa ficar na pílula.",
                how: "O lápis está na orelha direita, junto ao recorte. Toque para editar. Toque de novo ou «Concluir» para sair."
            )
        case .guide:
            return GuideCopy(
                why: "Dá para abrir este tour de novo se algo escapar.",
                how: "O botão fica ao lado do lápis. Toque para começar do início. Durante o tour, o mesmo toque fecha."
            )
        case .mic:
            return GuideCopy(
                why: "Zoom e Discord têm mute próprio — é fácil esquecer qual está ligado.",
                how: "O toque silencia a entrada do Mac em todos os apps. Microfone branco: te ouvem. Vermelho no branco: não."
            )
        case .clipboard:
            return GuideCopy(
                why: "Os últimos textos copiados não somem na hora.",
                how: "O ícone da área de transferência está na orelha direita. Toque para a lista; toque numa linha para copiar de novo."
            )
        case .media:
            return GuideCopy(
                why: "Capa e título mostram o que está tocando.",
                how: "Embaixo do recorte. Toque na capa para abrir o player."
            )
        case .transport:
            return GuideCopy(
                why: "O controle da faixa fica na ilha grande, não na cápsula.",
                how: "Voltar, pausa, próxima. Se as animações estiverem ligadas na edição, pausa e pular acendem."
            )
        case .audio:
            return GuideCopy(
                why: "A música já está na ilha; ainda assim você troca de fone para alto-falante.",
                how: "A cápsula fica depois do transporte. Um círculo só se o aparelho existe: caixas, fones, MacBook, carro. O ativo é branco."
            )
        case .lyrics:
            return GuideCopy(
                why: "A letra não cabe na ilha; lê-se ao lado.",
                how: "O balão fica ao lado do transporte. Se não houver texto, o botão some ou não responde."
            )
        case .playlist:
            return GuideCopy(
                why: "A ilha mostra uma faixa, não o que vem depois.",
                how: "O botão da lista só aparece se o Music entregar a playlist atual. Toque abre a janela; a faixa atual fica marcada."
            )
        case .progress:
            return GuideCopy(
                why: "Quanto já passou e quanto falta, sem abrir o player.",
                how: "A barra fica embaixo da ilha grande. Arraste para pular na faixa."
            )
        case .editTray:
            return GuideCopy(
                why: "Botões tirados não se perdem — esperam na bandeja debaixo da ilha.",
                how: "Toque num botão da ilha para mandar à bandeja. Toque numa ficha para devolver. O brilho liga a animação de pausa e pular. «Concluir» sai da edição."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "A letra lê-se ao lado da ilha, não dentro da cápsula.",
                how: "O painel é de vidro, com um fechar. Dá para mover. A música continua."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Tem quem queira janela pequena; tem quem precise das linhas mais cedo ou mais tarde — não há um tamanho só.",
                how: "Arraste o círculo branco no canto para redimensionar."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Às vezes as linhas vão na frente da música, ou atrasadas.",
                how: "Menos — mais tarde. Mais — mais cedo. O deslocamento fica guardado nesta música."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "A fila inteira, não só a faixa atual.",
                how: "O nome da playlist fica em cima; a faixa atual está marcada. Toque numa linha para tocar."
            )
        case .end:
            return GuideCopy(
                why: "Dá para fechar o tour e usar a ilha.",
                how: "Bom uso. O botão do guia abre isto de novo."
            )
        }
    }
}
