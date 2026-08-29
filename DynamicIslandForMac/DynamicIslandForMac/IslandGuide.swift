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
    case collapsedSchedule
    case moses
    case appear
    case relocate
    case relocateDock
    case relocateHome
    case timer
    case schedule
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
        if state.shows(.schedule) {
            next.append(.collapsedSchedule)
        }
        next.append(.moses)
        next.append(.appear)
        next.append(.relocate)
        next.append(.relocateDock)
        next.append(.relocateHome)
        if state.shows(.timer) {
            next.append(.timer)
        }
        if state.shows(.schedule) {
            next.append(.schedule)
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
        case .capsule, .collapsedMusic, .collapsedTimer, .collapsedSchedule, .appear, .relocate:
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
                why: "Это Insula, свёрнутая в маленькую капсулу.",
                how: "Она сидит у выреза камеры и показывает, что сейчас активно — музыку или таймер, — без необходимости её открывать."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Видно, что что-то играет, даже не открывая Insula.",
                how: "Пока играет музыка, слева на капсуле показаны название трека и небольшая полоса прогресса."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "Таймер продолжает идти, даже пока Insula маленькая.",
                how: "Оставшееся время показано справа на капсуле. Чтобы поставить новый таймер, откройте Insula."
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "Следующая встреча или задача видна без открытия Календаря.",
                how: "Справа на капсуле — название и время или «через N мин». За 15 и 5 минут до события придёт уведомление."
            )
        case .moses:
            return GuideCopy(
                why: "Капсула лежит поверх строки меню и адресной строки браузера, поэтому может мешать кликам под собой.",
                how: "Если подводить курсор медленно снизу, весь остров сжимается вверх и освобождает место под собой. Если подвести быстро — сжатия не будет."
            )
        case .appear:
            return GuideCopy(
                why: "Insula не должна раскрываться от любого движения курсора рядом с камерой — но и не должна «тормозить», когда она правда нужна.",
                how: "Быстрый проход мимо не откроет её — задержите курсор примерно на 0.1 секунды. При медленном приближении остров сначала сжимается снизу, а полностью раскрывается только в верхней трети, у самой камеры."
            )
        case .relocate:
            return GuideCopy(
                why: "Insula можно перенести в другое место на экране.",
                how: "Кликните по нему три раза подряд быстро, в течение примерно полутора секунд, — и она начнёт следовать за курсором."
            )
        case .relocateDock:
            return GuideCopy(
                why: "У края экрана Insula прилипает к этому краю, а не зависает посреди экрана.",
                how: "После тройного клика подождите около двух секунд и кликните один раз — Insula по прямой полетит к ближайшему краю. Внизу она становится пилюлей, сбоку — карточкой."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Эта кнопка сразу возвращает Insula к вырезу камеры.",
                how: "Найдите маленькую иконку домика рядом с вырезом. Один клик — и Insula дома."
            )
        case .timer:
            return GuideCopy(
                why: "Здесь ставится обратный отсчёт — а не в приложении «Часы» и не где-то ещё.",
                how: "Слева: часы, минуты, секунды. По окончании — звук и уведомление; музыка, если играла, ставится на паузу, а потом снова включается."
            )
        case .schedule:
            return GuideCopy(
                why: "Календарь и Напоминания macOS — в одном месте на Insula.",
                how: "«Следующее», список встреч и задач на сегодня. Нажмите строку — откроется Календарь или Reminders. Можно включить рабочие часы и выбрать календари."
            )
        case .edit:
            return GuideCopy(
                why: "Не всем нужны все кнопки сразу. Лишние необязательно держать на капсуле.",
                how: "Нажмите на значок карандаша справа, рядом с вырезом, чтобы войти в режим редактирования. Нажмите ещё раз или на «Готово», чтобы выйти."
            )
        case .guide:
            return GuideCopy(
                why: "Этот тур можно открыть заново в любой момент, если что-то забылось.",
                how: "Кнопка находится рядом с карандашом. Нажмите, чтобы начать сначала. Пока тур идёт, то же нажатие его закрывает."
            )
        case .mic:
            return GuideCopy(
                why: "В Zoom, Discord и любом другом приложении своя отдельная кнопка mute — легко забыть, где она включена.",
                how: "Нажатие сразу выключает микрофон Mac для всех приложений. Обычный белый значок микрофона — вас слышно. Красный значок на белом фоне — вы выключены."
            )
        case .clipboard:
            return GuideCopy(
                why: "Скопированный текст не пропадает сразу же, как только вы скопируете что-то новое.",
                how: "Значок буфера обмена справа. Нажмите на него, чтобы увидеть последние скопированные фрагменты, и на любой из них — чтобы скопировать снова."
            )
        case .media:
            return GuideCopy(
                why: "Обложка и название трека показывают, что играет прямо сейчас.",
                how: "Они расположены под вырезом камеры. Нажмите на обложку, чтобы открыть полноценный плеер."
            )
        case .transport:
            return GuideCopy(
                why: "Управление воспроизведением находится на развёрнутой Insula, а не на маленькой капсуле.",
                how: "Назад, пауза, вперёд. Если в режиме редактирования включены анимации, кнопки паузы и перемотки подсвечиваются при использовании."
            )
        case .audio:
            return GuideCopy(
                why: "Музыка уже управляется с Insula, но иногда нужно переключиться, например, с наушников на колонки.",
                how: "Этот элемент идёт сразу после кнопок воспроизведения. Значок устройства появляется, только если оно реально доступно: колонки, наушники, MacBook или машина. Активное устройство показано белым."
            )
        case .lyrics:
            return GuideCopy(
                why: "Текст песни не помещается в Insula, поэтому он открывается рядом, в отдельном окне.",
                how: "Нажмите на значок в виде облачка рядом с кнопками воспроизведения. Если для текущей песни текста нет, кнопка скрыта или неактивна."
            )
        case .playlist:
            return GuideCopy(
                why: "Insula показывает только текущий трек, а не то, что будет играть дальше.",
                how: "Значок списка появляется, только если Music поделился текущим плейлистом. Нажмите на него, чтобы открыть окно со всей очередью; играющий сейчас трек подсвечен."
            )
        case .progress:
            return GuideCopy(
                why: "Видно, сколько трека уже прошло и сколько осталось, — без открытия полноценного плеера.",
                how: "Полоса прогресса находится под кнопками управления на развёрнутой Insula. Потяните её, чтобы перейти к другому моменту песни."
            )
        case .editTray:
            return GuideCopy(
                why: "Убранная кнопка не удаляется навсегда — она просто уходит с глаз в лоток.",
                how: "В режиме редактирования нажмите на кнопку на Insula, чтобы отправить её в лоток снизу. Нажмите на плитку в лотке, чтобы вернуть кнопку обратно. Значок-искра включает или выключает подсветку паузы и перемотки. «Готово» завершает редактирование."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "Текст песни читают рядом с Insula, а не внутри маленькой капсулы.",
                how: "Это полупрозрачная панель со своей кнопкой закрытия — её можно перетаскивать по экрану. Музыка при этом продолжает играть."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Кому-то удобнее маленькое окно, а кому-то нужно видеть больше строк сразу — единого размера нет.",
                how: "Потяните за маленький белый кружок в углу, чтобы изменить размер панели."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Иногда строки текста опережают музыку или отстают от неё.",
                how: "Минус задерживает текст, плюс — сдвигает его раньше. Эта настройка запоминается отдельно для каждой песни."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "Здесь показана вся очередь треков, а не только тот, что играет сейчас.",
                how: "Название плейлиста — сверху, текущий трек подсвечен. Нажмите на любой трек в списке, чтобы включить именно его."
            )
        case .end:
            return GuideCopy(
                why: "На этом тур закончен — можно пользоваться Insula самостоятельно.",
                how: "Приятного использования. Этот гайд можно снова открыть кнопкой гайда."
            )
        }
    }

    private static func es(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "Esta es Insula reducida a una pequeña cápsula.",
                how: "Se coloca sobre la cámara y muestra lo que está activo —música o un temporizador— sin que tengas que abrirla."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Se nota si algo está sonando sin necesidad de abrir Insula.",
                how: "El nombre del tema y una pequeña barra de progreso aparecen a la izquierda de la cápsula mientras suena música."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "El temporizador sigue corriendo aunque Insula esté pequeña.",
                how: "El tiempo restante aparece a la derecha de la cápsula. Abre Insula para poner uno nuevo."
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "La próxima reunión o tarea se ve sin abrir Calendario.",
                how: "A la derecha de la cápsula: título y hora o «en N min». Aviso 15 y 5 minutos antes."
            )
        case .moses:
            return GuideCopy(
                why: "La cápsula queda encima de la barra de menú y de la barra de direcciones, así que puede bloquear los clics de lo que hay debajo.",
                how: "Si te acercas despacio por abajo, toda la isla se comprime hacia arriba y deja sitio debajo. Si llegas rápido, no se comprime."
            )
        case .appear:
            return GuideCopy(
                why: "Insula no debería abrirse cada vez que el cursor pasa cerca de la cámara, pero tampoco debería sentirse lenta cuando de verdad la quieres usar.",
                how: "Un simple paso rápido no la abre: quédate sobre ella unos 0,1 segundos. Si te acercas despacio, primero la isla se comprime por abajo y luego se abre del todo, cerca de la parte superior, junto a la cámara."
            )
        case .relocate:
            return GuideCopy(
                why: "Puedes mover Insula a otro punto de la pantalla.",
                how: "Haz tres clics rápidos seguidos, en poco más de un segundo, y empezará a seguir al cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "Cerca de un borde de la pantalla, Insula se pega a ese borde en vez de quedar flotando en medio.",
                how: "Después del triple clic, espera unos dos segundos y haz un clic más: se desliza en línea recta hasta el borde más cercano. Abajo se convierte en píldora; al lado, en tarjeta."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Este botón devuelve Insula directamente a la cámara.",
                how: "Busca el pequeño icono de casa junto al recorte. Un clic y vuelve a su sitio."
            )
        case .timer:
            return GuideCopy(
                why: "Aquí es donde se pone una cuenta atrás, no en la app Reloj ni en otro sitio.",
                how: "A la izquierda: horas, minutos y segundos. Al terminar suena un aviso y llega una notificación; si había música sonando, se pausa y luego sigue."
            )
        case .schedule:
            return GuideCopy(
                why: "Calendario y Recordatorios de macOS en un solo lugar en Insula.",
                how: "«Siguiente», reuniones y tareas de hoy. Toca una fila para abrir Calendario o Recordatorios. Puedes activar horario laboral y elegir calendarios."
            )
        case .edit:
            return GuideCopy(
                why: "No todo el mundo necesita todos los botones. Lo que sobra no tiene por qué quedarse en la cápsula.",
                how: "Toca el icono del lápiz a la derecha, junto al recorte, para entrar en modo edición. Tócalo otra vez, o toca «Listo», para salir."
            )
        case .guide:
            return GuideCopy(
                why: "Puedes volver a abrir este recorrido cuando quieras si se te olvida algo.",
                how: "El botón está junto al lápiz. Tócalo para empezar de nuevo desde el principio. Mientras el recorrido está en marcha, el mismo toque lo cierra."
            )
        case .mic:
            return GuideCopy(
                why: "Zoom, Discord y cualquier otra app tienen su propio botón de silencio, y es fácil perder de vista cuál está activado.",
                how: "Tócalo para silenciar el micrófono del Mac en todas las apps a la vez. Un icono de micrófono blanco significa que se te oye. Uno rojo sobre blanco significa que estás silenciado."
            )
        case .clipboard:
            return GuideCopy(
                why: "El texto que copias no desaparece en cuanto copias otra cosa.",
                how: "El icono del portapapeles está a la derecha. Tócalo para ver lo copiado recientemente, y toca cualquier entrada para copiarla de nuevo."
            )
        case .media:
            return GuideCopy(
                why: "La carátula y el título muestran lo que suena en este momento.",
                how: "Aparecen debajo del recorte. Toca la carátula para abrir el reproductor completo."
            )
        case .transport:
            return GuideCopy(
                why: "Los controles de reproducción están en Insula grande, no en la cápsula pequeña.",
                how: "Atrás, pausa y siguiente. Si las animaciones están activadas en modo edición, pausa y siguiente se iluminan al usarlos."
            )
        case .audio:
            return GuideCopy(
                why: "La música ya se controla desde Insula, pero a veces necesitas cambiar, por ejemplo, de auriculares a altavoces.",
                how: "Esto va justo después de los controles de reproducción. Un icono de dispositivo solo aparece si ese dispositivo está realmente disponible: altavoces, auriculares, tu MacBook o un coche. El que está en uso se muestra en blanco."
            )
        case .lyrics:
            return GuideCopy(
                why: "La letra no cabe dentro de Insula, así que se abre aparte, al lado.",
                how: "Toca el icono del globo de texto junto a los controles de reproducción. Si la canción no tiene letra disponible, el botón queda oculto o no responde."
            )
        case .playlist:
            return GuideCopy(
                why: "Insula muestra el tema actual, no lo que viene después.",
                how: "El icono de lista solo aparece si Music comparte la lista de reproducción actual. Tócalo para abrir una ventana con toda la cola; el tema actual queda resaltado."
            )
        case .progress:
            return GuideCopy(
                why: "Puedes ver cuánto ha pasado del tema y cuánto queda, sin abrir el reproductor completo.",
                how: "La barra está debajo de los controles, en Insula grande. Arrástrala para saltar a otro punto de la canción."
            )
        case .editTray:
            return GuideCopy(
                why: "Quitar un botón no lo borra: solo lo aparta a una bandeja.",
                how: "En modo edición, toca un botón de Insula para mandarlo a la bandeja de abajo. Toca una ficha de la bandeja para devolverlo. El icono de chispa activa o desactiva la animación de pausa y salto. Toca «Listo» para salir del modo edición."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "La letra se lee al lado de Insula, no metida dentro de la cápsula pequeña.",
                how: "Es un panel translúcido con su propio botón de cerrar, y puedes arrastrarlo a cualquier parte de la pantalla. La música sigue sonando mientras está abierto."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "A algunas personas les viene bien una ventana pequeña; otras quieren ver más líneas a la vez: no hay un tamaño único.",
                how: "Arrastra el pequeño círculo blanco de la esquina para cambiar el tamaño del panel."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "A veces la letra va un poco por delante, o por detrás, de la música.",
                how: "El signo menos retrasa la letra; el más la adelanta. Este ajuste se recuerda para esa canción en concreto."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "Aquí se ve toda la cola que viene después, no solo el tema que suena ahora.",
                how: "El nombre de la lista aparece arriba, y el tema actual queda resaltado. Toca cualquier tema para reproducirlo."
            )
        case .end:
            return GuideCopy(
                why: "Con esto termina el recorrido: ya puedes usar Insula por tu cuenta.",
                how: "Que la disfrutes. Puedes volver a abrir esta guía cuando quieras desde el botón de guía."
            )
        }
    }

    private static func en(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "This is Insula collapsed down to a small capsule.",
                how: "It sits over the camera and shows what's active — music or a timer — without you opening it."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "You can tell something is playing without opening Insula.",
                how: "The track name and a small progress bar appear on the left side of the capsule while music plays."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "The timer keeps running even while Insula stays small.",
                how: "The time left shows on the right side of the capsule. Open Insula to start a new one."
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "Your next meeting or task is visible without opening Calendar.",
                how: "On the right of the capsule: title and time or «in N min». Notifications 15 and 5 minutes before."
            )
        case .moses:
            return GuideCopy(
                why: "The capsule sits on top of your menu bar and address bar, so it can block clicks underneath it.",
                how: "Approach slowly from below and the whole island compresses upward, freeing space underneath. Approach fast and it won't compress."
            )
        case .appear:
            return GuideCopy(
                why: "Insula shouldn't pop open every time your cursor passes near the camera, but it shouldn't feel slow either when you actually want it.",
                how: "A quick pass-by won't open it — pause on it for about 0.1 seconds. Moving in slowly compresses the island first, then opens the full Insula near the top, right by the camera."
            )
        case .relocate:
            return GuideCopy(
                why: "You can move Insula to a different spot on the screen.",
                how: "Click it three times quickly, within about a second and a half, and it starts following your cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "Near a screen edge, Insula snaps to that edge instead of floating in the middle of the screen.",
                how: "After the triple-click, wait about two seconds, then click once — it slides straight to the nearest edge. At the bottom it becomes a pill; on the side, a card."
            )
        case .relocateHome:
            return GuideCopy(
                why: "This brings Insula straight back to the camera notch.",
                how: "Look for the small house icon near the notch. One click and it's back home."
            )
        case .timer:
            return GuideCopy(
                why: "This is where you set a countdown — not the Clock app, not somewhere else.",
                how: "On the left side: hours, minutes, seconds. When it ends you get a sound and a notification; any music playing pauses, then resumes."
            )
        case .schedule:
            return GuideCopy(
                why: "macOS Calendar and Reminders in one glance on Insula.",
                how: "«Next up», today's meetings and tasks. Tap a row to open Calendar or Reminders. Optional work hours and calendar filters."
            )
        case .edit:
            return GuideCopy(
                why: "Not everyone needs every button. Anything extra doesn't have to stay on the capsule.",
                how: "Tap the pencil icon on the right side, near the notch, to enter edit mode. Tap it again, or tap Done, to leave."
            )
        case .guide:
            return GuideCopy(
                why: "You can reopen this tour any time if you forget how something works.",
                how: "The button sits next to the pencil. Tap it to start over from the beginning. While the tour is running, the same tap closes it."
            )
        case .mic:
            return GuideCopy(
                why: "Zoom, Discord, and every other app has its own separate mute button — easy to lose track of which one is on.",
                how: "Tap this to mute your Mac's microphone for every app at once. A plain white mic icon means people can hear you. A red mic on white means you're muted."
            )
        case .clipboard:
            return GuideCopy(
                why: "Text you've copied doesn't just vanish the moment you copy something new.",
                how: "The clipboard icon is on the right side. Tap it to see recent copies, then tap any entry to copy it again."
            )
        case .media:
            return GuideCopy(
                why: "The artwork and title show you what's playing right now.",
                how: "They sit below the notch. Tap the artwork to open the full player."
            )
        case .transport:
            return GuideCopy(
                why: "Track controls live on the full-size Insula, not on the small capsule.",
                how: "Back, pause, and next. If animations are turned on in edit mode, pause and skip glow when you use them."
            )
        case .audio:
            return GuideCopy(
                why: "Music is already on Insula, but you still need to switch between things like headphones and speakers.",
                how: "This sits right after the playback buttons. A device icon only appears if that device is actually available: speakers, headphones, your MacBook, or a car. The one you're using is shown in white."
            )
        case .lyrics:
            return GuideCopy(
                why: "Lyrics don't fit inside Insula, so they open in a separate space next to it.",
                how: "Tap the speech-bubble icon next to the playback controls. If there are no lyrics for the current song, the button is hidden or does nothing."
            )
        case .playlist:
            return GuideCopy(
                why: "Insula shows you the current track, not what's coming up next.",
                how: "The list icon only appears if Music shares its current playlist. Tap it to open a window with the full queue; the current track is highlighted."
            )
        case .progress:
            return GuideCopy(
                why: "See how far into the track you are, and how much is left, without opening the full player.",
                how: "The bar sits below the controls on the full-size Insula. Drag it to jump to a different point in the song."
            )
        case .editTray:
            return GuideCopy(
                why: "Removing a button doesn't delete it — it just moves out of the way, into a tray.",
                how: "In edit mode, tap a button on Insula to send it to the tray below. Tap a tile in the tray to bring it back. The sparkle icon turns the pause/skip glow animation on or off. Tap Done to leave edit mode."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "Lyrics are read next to Insula, not squeezed inside the small capsule.",
                how: "It's a translucent panel with its own close button, and you can drag it anywhere on screen. Music keeps playing while it's open."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Some people want a small window; others want to see more lines at once — there's no single right size.",
                how: "Drag the small white circle in the corner to resize the panel."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Sometimes the lyrics run a little ahead of, or behind, the music.",
                how: "Minus delays the lyrics, plus brings them earlier. This adjustment is remembered for that specific song."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "This shows the whole upcoming queue, not just the track playing right now.",
                how: "The playlist name is at the top, and the current track is highlighted. Tap any track to play it."
            )
        case .end:
            return GuideCopy(
                why: "That's the whole tour — you're ready to use Insula on your own.",
                how: "Enjoy. You can reopen this guide any time from the guide button."
            )
        }
    }

    private static func zh(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "这是缩成小胶囊状态的 Insula。",
                how: "它贴在摄像头位置，会显示当前有什么在活动——比如音乐或计时器——不需要你把它展开。"
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "不用展开Insula，也能看出是否有音乐在播放。",
                how: "播放音乐时，胶囊左侧会显示歌曲名和一小段进度条。"
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "即使Insula保持很小，计时器也会继续走。",
                how: "剩余时间显示在胶囊右侧。要设置新的计时器，需要先展开Insula。"
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "不用打开日历也能看到下一个会议或任务。",
                how: "胶囊右侧显示标题和时间或「N分钟后」。事件前15和5分钟会收到通知。"
            )
        case .moses:
            return GuideCopy(
                why: "胶囊盖在菜单栏和地址栏上方，可能会挡住下面的点击。",
                how: "从下方慢慢靠近时，整个胶囊会向上压缩，让出下面的空间。如果很快划过，就不会压缩。"
            )
        case .appear:
            return GuideCopy(
                why: "Insula 不应该因为光标随便经过摄像头附近就弹开，但真正想用它时也不能反应慢。",
                how: "快速经过不会展开它——需要在上面停留大约 0.1 秒。慢慢靠近时，胶囊会先向下压缩，然后才会在最上方、摄像头旁边完全展开。"
            )
        case .relocate:
            return GuideCopy(
                why: "你可以把 Insula移动到屏幕上的其他位置。",
                how: "在大约一秒半内连续快速点击三次，Insula 就会开始跟着光标移动。"
            )
        case .relocateDock:
            return GuideCopy(
                why: "靠近屏幕边缘时，Insula 会贴到那条边上，而不是停在屏幕正中间。",
                how: "三连击之后，等大约两秒，再点一下——Insula 会沿直线滑到最近的边缘。停在底部时是胶囊形状，停在侧边时是卡片形状。"
            )
        case .relocateHome:
            return GuideCopy(
                why: "这个按钮会让 Insula立刻回到摄像头位置。",
                how: "在刘海旁边找一个小房子图标。点一下，Insula 就回到原位了。"
            )
        case .timer:
            return GuideCopy(
                why: "倒计时是在这里设置的，不是在“时钟”App，也不是别的地方。",
                how: "左侧可以设置小时、分钟、秒。倒计时结束时会有声音提示和系统通知；如果正在播放音乐，会先暂停再继续播放。"
            )
        case .schedule:
            return GuideCopy(
                why: "macOS日历和提醒事项，在Insula上一目了然。",
                how: "「下一个」、今天的会议和任务。点一行打开日历或提醒事项。可设工作时间和筛选日历。"
            )
        case .edit:
            return GuideCopy(
                why: "不是所有人都需要用到全部按钮，用不到的完全可以从胶囊上拿掉。",
                how: "点右侧靠近刘海的铅笔图标，进入编辑模式。再点一次，或者点「完成」，即可退出。"
            )
        case .guide:
            return GuideCopy(
                why: "如果忘了某个功能怎么用，随时可以重新打开这个导览。",
                how: "按钮就在铅笔图标旁边。点一下从头开始播放导览；导览进行中再点同一个按钮会直接关闭它。"
            )
        case .mic:
            return GuideCopy(
                why: "Zoom、Discord 等每个 App 都有自己独立的静音按钮，很容易记不清哪个开着。",
                how: "点一下就能一次性把 Mac 麦克风对所有 App 静音。普通白色麦克风图标表示对方能听到你；白底红色图标表示你已静音。"
            )
        case .clipboard:
            return GuideCopy(
                why: "复制的文字不会因为你又复制了新内容就立刻消失。",
                how: "剪贴板图标在右侧。点开可以看到最近复制的内容，点其中任意一条即可重新复制它。"
            )
        case .media:
            return GuideCopy(
                why: "封面图和歌曲名会告诉你现在正在播放什么。",
                how: "它们显示在刘海下方。点封面图可以打开完整的播放器界面。"
            )
        case .transport:
            return GuideCopy(
                why: "播放控制按钮在展开的 Insula上，小胶囊上没有。",
                how: "上一首、暂停、下一首。如果在编辑模式里打开了动画效果，使用暂停和切歌时按钮会有发光提示。"
            )
        case .audio:
            return GuideCopy(
                why: "音乐播放已经能在Insula 上控制，但有时你还需要在耳机和扬声器之间切换。",
                how: "这个控件紧跟在播放按钮后面。只有设备真的可用时才会显示对应图标：扬声器、耳机、你的 MacBook 或车载音响。正在使用的那个会显示为白色。"
            )
        case .lyrics:
            return GuideCopy(
                why: "歌词放不进Insula 里，所以会在旁边单独打开一块区域显示。",
                how: "点播放按钮旁边的气泡图标。如果当前歌曲没有歌词，这个按钮会隐藏或点了没反应。"
            )
        case .playlist:
            return GuideCopy(
                why: "Insula 上只显示当前这一首歌，不会显示接下来要播放的内容。",
                how: "只有当“音乐”App 提供了当前播放列表时，列表图标才会出现。点开会显示整个播放队列的窗口，正在播放的曲目会高亮显示。"
            )
        case .progress:
            return GuideCopy(
                why: "不用打开完整播放器，也能看到这首歌播放了多久、还剩多少。",
                how: "进度条在Insula展开后位于控制按钮下方。拖动它可以跳到歌曲的其他位置。"
            )
        case .editTray:
            return GuideCopy(
                why: "拿掉一个按钮并不会删除它，只是把它挪到旁边的托盘里放着。",
                how: "编辑模式下，点Insula 上的按钮可以把它送进下面的托盘；点托盘里的按钮可以把它放回去。星光图标用来开关暂停/切歌的发光动画。点「完成」退出编辑模式。"
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "歌词是在Insula 旁边单独阅读的，不是挤在小胶囊里面。",
                how: "这是一个半透明面板，有自己的关闭按钮，可以拖到屏幕任意位置。打开它时音乐会继续播放。"
            )
        case .lyricsResize:
            return GuideCopy(
                why: "有人喜欢小窗口，有人想一次看到更多行歌词——没有一个统一合适的大小。",
                how: "拖动面板角落的白色小圆点，即可调整大小。"
            )
        case .lyricsSync:
            return GuideCopy(
                why: "有时歌词会比音乐快一点，或者慢一点。",
                how: "点减号让歌词延后，点加号让歌词提前。这个偏移量会针对这首歌单独记住。"
            )
        case .playlistPanel:
            return GuideCopy(
                why: "这里显示的是接下来整个播放队列，不只是当前这一首。",
                how: "顶部是播放列表名称，当前曲目会高亮显示。点列表里的任意一首即可播放它。"
            )
        case .end:
            return GuideCopy(
                why: "导览到这里就结束了，你可以自己使用Insula了。",
                how: "祝使用愉快。随时可以通过导览按钮再次打开这份指南。"
            )
        }
    }

    private static func ja(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "これはカプセル状に折りたたまれた状態の Insula です。",
                how: "カメラの位置に表示され、開かなくても音楽やタイマーなど今動いているものがわかります。"
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Insula を開かなくても、何か再生中かどうかが一目でわかります。",
                how: "音楽再生中は、カプセルの左側に曲名と小さな進捗バーが表示されます。"
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "Insula が小さいままでも、タイマーは動き続けます。",
                how: "残り時間はカプセルの右側に表示されます。新しいタイマーを設定するには Insula を開いてください。"
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "カレンダーを開かなくても次の予定やタスクが見えます。",
                how: "カプセル右側にタイトルと時刻、または「あとN分」。15分前と5分前に通知が届きます。"
            )
        case .moses:
            return GuideCopy(
                why: "カプセルはメニューバーやアドレスバーの上に重なっているため、下にあるものへのクリックを塞いでしまうことがあります。",
                how: "下からゆっくり近づくと、島全体が上に押し込まれて下にスペースができます。素早く近づくと押し込まれません。"
            )
        case .appear:
            return GuideCopy(
                why: "カメラ付近をカーソルが通っただけで毎回開いてしまうのも、逆に本当に開きたいときに反応が遅いのも困ります。",
                how: "サッと通り過ぎただけでは開きません。約0.1秒とどまる必要があります。ゆっくり近づくと、まず島が下から押し込まれ、カメラのすぐそば・上部三分の一の範囲でだけ完全に開きます。"
            )
        case .relocate:
            return GuideCopy(
                why: "Insula は画面の別の場所に動かすことができます。",
                how: "約1.5秒以内に素早く3回クリックすると、カーソルについてくるようになります。"
            )
        case .relocateDock:
            return GuideCopy(
                why: "画面の端に近づけると、中央に浮いたままにならず、その端にぴったり収まります。",
                how: "3回クリックしたあと約2秒待ってからもう1回クリックすると、最も近い端まで一直線に移動します。下端ではピル形に、側面ではカード形になります。"
            )
        case .relocateHome:
            return GuideCopy(
                why: "このボタンは Insula をすぐカメラの位置に戻します。",
                how: "切り欠きの近くにある小さな家のアイコンを探してください。1回クリックするだけで元の位置に戻ります。"
            )
        case .timer:
            return GuideCopy(
                why: "カウントダウンはここで設定します。「時計」アプリなど別の場所ではありません。",
                how: "左側で時・分・秒を設定します。終了すると音と通知が鳴り、再生中の音楽は一時停止したあと再び再生されます。"
            )
        case .schedule:
            return GuideCopy(
                why: "macOSのカレンダーとリマインダーを Insula で一覧できます。",
                how: "「次」、今日の予定とタスク。行をタップするとカレンダーまたはリマインダーが開きます。勤務時間とカレンダー選択も可能です。"
            )
        case .edit:
            return GuideCopy(
                why: "すべてのボタンが全員に必要なわけではありません。使わないものはカプセルに置いておく必要はありません。",
                how: "切り欠き近くの右側にある鉛筆アイコンをタップすると編集モードに入ります。もう一度タップするか「完了」をタップすると終了します。"
            )
        case .guide:
            return GuideCopy(
                why: "使い方を忘れたときは、いつでもこのツアーをもう一度開けます。",
                how: "ボタンは鉛筆アイコンの隣にあります。タップすると最初からやり直せます。ツアー中に同じボタンをタップすると閉じます。"
            )
        case .mic:
            return GuideCopy(
                why: "Zoom や Discord など、アプリごとに別々のミュートボタンがあり、どれがオンになっているか忘れがちです。",
                how: "タップすると Mac のマイクをすべてのアプリに対して一括でミュートできます。白いマイクのアイコンは相手に聞こえている状態、白地に赤いマイクはミュート中を示します。"
            )
        case .clipboard:
            return GuideCopy(
                why: "コピーしたテキストは、新しく何かをコピーしてもすぐには消えません。",
                how: "クリップボードのアイコンは右側にあります。タップすると最近コピーした内容が一覧表示され、好きな項目をタップするともう一度コピーできます。"
            )
        case .media:
            return GuideCopy(
                why: "アートワークと曲名で、今何が再生されているかがわかります。",
                how: "切り欠きの下に表示されます。アートワークをタップするとフルプレーヤーが開きます。"
            )
        case .transport:
            return GuideCopy(
                why: "曲の操作ボタンは大きく展開した Insula にあり、小さいカプセルにはありません。",
                how: "戻る・一時停止・次へ、の3つです。編集モードでアニメーションをオンにしていると、一時停止とスキップのボタンが操作時に光ります。"
            )
        case .audio:
            return GuideCopy(
                why: "音楽の操作はすでに Insula でできますが、ヘッドホンとスピーカーの切り替えなどはまた別です。",
                how: "再生コントロールのすぐ後ろに表示されます。実際に使える機器がある場合だけアイコンが出ます：スピーカー、ヘッドホン、MacBook本体、車のオーディオなど。現在使用中の機器は白く表示されます。"
            )
        case .lyrics:
            return GuideCopy(
                why: "歌詞は Insula の中に収まらないため、隣に別のスペースで開きます。",
                how: "再生コントロールの隣にある吹き出しアイコンをタップします。その曲に歌詞がない場合、ボタンは非表示になるか反応しません。"
            )
        case .playlist:
            return GuideCopy(
                why: "Insula に表示されるのは今の1曲だけで、次に流れる曲まではわかりません。",
                how: "リストアイコンは、ミュージックが現在のプレイリスト情報を渡しているときだけ表示されます。タップするとキュー全体のウィンドウが開き、再生中の曲がハイライトされます。"
            )
        case .progress:
            return GuideCopy(
                why: "フルプレーヤーを開かなくても、曲がどこまで進んでどれくらい残っているかがわかります。",
                how: "バーは大きく展開した Insula の、コントロールの下にあります。ドラッグすると曲の別の位置に移動できます。"
            )
        case .editTray:
            return GuideCopy(
                why: "ボタンを外しても削除されるわけではなく、下のトレイに移動するだけです。",
                how: "編集モード中に Insula 上のボタンをタップするとトレイへ送られます。トレイのタイルをタップすると元に戻せます。キラキラのアイコンは一時停止・スキップの発光アニメーションのオン/オフ切り替えです。「完了」をタップすると編集モードを終了します。"
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "歌詞は小さなカプセルの中ではなく、Insula の隣で読む形になっています。",
                how: "半透明のパネルで、専用の閉じるボタンがあり、画面上の好きな場所にドラッグできます。開いている間も音楽は再生され続けます。"
            )
        case .lyricsResize:
            return GuideCopy(
                why: "小さいウィンドウが好みの人もいれば、一度に多くの行を見たい人もいるため、決まった正解のサイズはありません。",
                how: "角にある小さな白い丸をドラッグするとパネルのサイズを変更できます。"
            )
        case .lyricsSync:
            return GuideCopy(
                why: "歌詞が音楽より少し早く、または遅れて表示されることがあります。",
                how: "マイナスで歌詞を遅らせ、プラスで早めます。この調整はその曲ごとに記憶されます。"
            )
        case .playlistPanel:
            return GuideCopy(
                why: "ここには今再生中の1曲だけでなく、この先のキュー全体が表示されます。",
                how: "上部にプレイリスト名が表示され、再生中の曲はハイライトされます。リスト内の曲をタップすると、その曲が再生されます。"
            )
        case .end:
            return GuideCopy(
                why: "これでツアーは終わりです。Insula を自分の手で使う準備ができました。",
                how: "どうぞお楽しみください。ガイドボタンからこのツアーはいつでも開き直せます。"
            )
        }
    }

    private static func pt(_ spot: GuideSpot) -> GuideCopy {
        switch spot {
        case .capsule:
            return GuideCopy(
                why: "Esta é Insula reduzida a uma pequena cápsula.",
                how: "Ela fica sobre a câmera e mostra o que está ativo — música ou um temporizador — sem que você precise abri-la."
            )
        case .collapsedMusic:
            return GuideCopy(
                why: "Dá para saber se algo está tocando sem precisar abrir Insula.",
                how: "O nome da faixa e uma pequena barra de progresso aparecem à esquerda da cápsula enquanto a música toca."
            )
        case .collapsedTimer:
            return GuideCopy(
                why: "O temporizador continua contando mesmo com Insula pequena.",
                how: "O tempo restante aparece à direita da cápsula. Abra Insula para definir um novo."
            )
        case .collapsedSchedule:
            return GuideCopy(
                why: "A próxima reunião ou tarefa aparece sem abrir o Calendário.",
                how: "À direita da cápsula: título e hora ou «em N min». Avisos 15 e 5 minutos antes."
            )
        case .moses:
            return GuideCopy(
                why: "A cápsula fica sobre a barra de menu e a barra de endereços, então pode bloquear cliques no que está embaixo dela.",
                how: "Aproxime-se devagar por baixo e a ilha inteira se comprime para cima, liberando espaço embaixo. Se chegar rápido, não comprime."
            )
        case .appear:
            return GuideCopy(
                why: "Insula não deveria se abrir toda vez que o cursor passa perto da câmera, mas também não deveria demorar quando você realmente quer usá-la.",
                how: "Só passar rápido por cima não abre Insula — fique parado nela por cerca de 0,1 segundo. Chegando devagar, primeiro a ilha se comprime por baixo, e Insula só abre por completo perto do topo, junto à câmera."
            )
        case .relocate:
            return GuideCopy(
                why: "Você pode mover Insula para outro lugar da tela.",
                how: "Clique nela três vezes rápido, em cerca de um segundo e meio, e ela passa a seguir o cursor."
            )
        case .relocateDock:
            return GuideCopy(
                why: "Perto de uma borda da tela, Insula gruda nessa borda em vez de ficar flutuando no meio.",
                how: "Depois do triplo clique, espere uns dois segundos e clique mais uma vez — ela desliza em linha reta até a borda mais próxima. Embaixo vira uma pílula; do lado, um cartão."
            )
        case .relocateHome:
            return GuideCopy(
                why: "Este botão traz Insula de volta para a câmera na hora.",
                how: "Procure o pequeno ícone de casa perto do recorte. Um clique e ela volta para o lugar."
            )
        case .timer:
            return GuideCopy(
                why: "É aqui que se configura uma contagem regressiva — não no app Relógio nem em outro lugar.",
                how: "Do lado esquerdo: horas, minutos, segundos. Quando termina, toca um som e chega uma notificação; se havia música tocando, ela pausa e depois volta."
            )
        case .schedule:
            return GuideCopy(
                why: "Calendário e Lembretes do macOS num só lugar na Insula.",
                how: "«Próximo», reuniões e tarefas de hoje. Toque numa linha para abrir Calendário ou Lembretes. Horário de trabalho e filtros de calendário opcionais."
            )
        case .edit:
            return GuideCopy(
                why: "Nem todo mundo precisa de todos os botões. O que sobra não precisa ficar na cápsula.",
                how: "Toque no ícone do lápis à direita, perto do recorte, para entrar no modo de edição. Toque de novo, ou toque em «Concluir», para sair."
            )
        case .guide:
            return GuideCopy(
                why: "Você pode abrir este tour de novo a qualquer momento, se esquecer como algo funciona.",
                how: "O botão fica ao lado do lápis. Toque para começar de novo, do início. Enquanto o tour está rodando, o mesmo toque o fecha."
            )
        case .mic:
            return GuideCopy(
                why: "Zoom, Discord e qualquer outro app têm seu próprio botão de mudo, e é fácil perder de vista qual está ativado.",
                how: "Toque aqui para silenciar o microfone do Mac em todos os apps de uma vez. Um ícone de microfone branco simples significa que dá para te ouvir. Um microfone vermelho sobre fundo branco significa que você está mudo."
            )
        case .clipboard:
            return GuideCopy(
                why: "O texto que você copia não some assim que você copia outra coisa.",
                how: "O ícone da área de transferência fica à direita. Toque nele para ver o que foi copiado recentemente, e toque em qualquer item para copiá-lo de novo."
            )
        case .media:
            return GuideCopy(
                why: "A capa e o título mostram o que está tocando agora.",
                how: "Eles ficam embaixo do recorte. Toque na capa para abrir o player completo."
            )
        case .transport:
            return GuideCopy(
                why: "Os controles de reprodução ficam na Insula grande, não na cápsula pequena.",
                how: "Voltar, pausar e avançar. Se as animações estiverem ativadas no modo de edição, pausar e pular acendem quando usados."
            )
        case .audio:
            return GuideCopy(
                why: "A música já é controlada pela Insula, mas às vezes você ainda precisa trocar, por exemplo, do fone para a caixa de som.",
                how: "Isso fica logo depois dos controles de reprodução. Um ícone de aparelho só aparece se ele estiver realmente disponível: caixa de som, fone, seu MacBook ou o carro. O que está em uso aparece em branco."
            )
        case .lyrics:
            return GuideCopy(
                why: "A letra não cabe dentro da Insula, então ela abre à parte, ao lado.",
                how: "Toque no ícone de balão de fala ao lado dos controles de reprodução. Se a música não tiver letra disponível, o botão fica escondido ou não faz nada."
            )
        case .playlist:
            return GuideCopy(
                why: "Insula mostra a faixa atual, não o que vem a seguir.",
                how: "O ícone de lista só aparece se o Music estiver compartilhando a playlist atual. Toque nele para abrir uma janela com a fila inteira; a faixa atual fica destacada."
            )
        case .progress:
            return GuideCopy(
                why: "Dá para ver quanto da faixa já passou e quanto falta, sem abrir o player completo.",
                how: "A barra fica abaixo dos controles, na Insula grande. Arraste-a para pular para outro ponto da música."
            )
        case .editTray:
            return GuideCopy(
                why: "Tirar um botão não o apaga — ele só vai para uma bandeja, fora do caminho.",
                how: "No modo de edição, toque em um botão da Insula para mandá-lo para a bandeja abaixo. Toque em um item da bandeja para trazê-lo de volta. O ícone de brilho liga ou desliga a animação de pausa/pular. Toque em «Concluir» para sair do modo de edição."
            )
        case .lyricsPanel:
            return GuideCopy(
                why: "A letra é lida ao lado da Insula, não espremida dentro da cápsula pequena.",
                how: "É um painel translúcido com seu próprio botão de fechar, e dá para arrastá-lo para qualquer lugar da tela. A música continua tocando enquanto ele está aberto."
            )
        case .lyricsResize:
            return GuideCopy(
                why: "Tem gente que prefere uma janela pequena; tem gente que quer ver mais linhas de uma vez — não existe um tamanho único certo.",
                how: "Arraste o pequeno círculo branco no canto para redimensionar o painel."
            )
        case .lyricsSync:
            return GuideCopy(
                why: "Às vezes a letra fica um pouco à frente, ou atrás, da música.",
                how: "O menos atrasa a letra, o mais a adianta. Esse ajuste fica salvo especificamente para aquela música."
            )
        case .playlistPanel:
            return GuideCopy(
                why: "Aqui aparece a fila inteira que vem a seguir, não só a faixa que está tocando agora.",
                how: "O nome da playlist fica em cima, e a faixa atual é destacada. Toque em qualquer faixa da lista para tocá-la."
            )
        case .end:
            return GuideCopy(
                why: "Esse foi o tour todo — agora você já pode usar Insula por conta própria.",
                how: "Bom uso. Você pode abrir este guia de novo quando quiser, pelo botão de guia."
            )
        }
    }
}
