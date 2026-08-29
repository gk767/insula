import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

final class LyricsManager: ObservableObject {

    struct Line: Identifiable, Equatable {
        let id: Int
        let time: Double?
        let text: String
    }

    @Published var available = false
    @Published var isOpen = false {
        didSet {
            if !isOpen {
                clearDroppedImage()
            }
        }
    }
    @Published var lines: [Line] = []
    @Published var panelSize: CGSize
    @Published var panelOrigin: CGPoint?
    @Published var userPlaced = false
    @Published var isResizing = false
    @Published var trackOffset: Double = 0
    /// Dropped onto the lyrics panel; kept until the panel closes. Not persisted.
    @Published var droppedImage: NSImage?
    var pinnedLeft: CGFloat = 0
    var pinnedTop: CGFloat = 0
    var onLiveFrame: (() -> Void)?

    static let defaultPanelSize = CGSize(width: 320, height: 120)
    static let minPanelSize = CGSize(width: 240, height: 88)
    static let maxPanelSize = CGSize(width: 560, height: 520)

    private var requestID = 0
    private var bag = Set<AnyCancellable>()
    private var lastKey = ""
    private static let widthKey = "lyrics.panel.w"
    private static let heightKey = "lyrics.panel.h"
    private static let xKey = "lyrics.panel.x"
    private static let yKey = "lyrics.panel.y"
    private static let placedKey = "lyrics.panel.placed"
    private static let offsetsKey = "lyrics.trackOffsets"

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
        if !isResizing {
            beginResize(left: panelOrigin?.x ?? 0, top: (panelOrigin?.y ?? 0) + panelSize.height)
        }
        let next = clamped(
            CGSize(
                width: start.width + (mouse.x - origin.x),
                height: start.height + (origin.y - mouse.y)
            )
        )
        panelSize = next
        // Keep model origin in sync with the pinned top-left while dragging.
        panelOrigin = CGPoint(x: pinnedLeft, y: pinnedTop - next.height)
        userPlaced = true
        onLiveFrame?()
    }

    func endResize() {
        userPlaced = true
        rememberOrigin(CGPoint(x: pinnedLeft, y: pinnedTop - panelSize.height))
        isResizing = false
        persistPanel()
        onLiveFrame?()
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

    func start(nowPlaying: NowPlayingManager) {
        nowPlaying.$title
            .combineLatest(nowPlaying.$artist, nowPlaying.$duration)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] title, artist, duration in
                self?.fetch(title: title, artist: artist, duration: duration)
            }
            .store(in: &bag)
    }

    func toggle() {
        guard available else { return }
        isOpen.toggle()
    }

    func clearDroppedImage() {
        if droppedImage != nil {
            droppedImage = nil
        }
    }

    func setDroppedImage(_ image: NSImage?) {
        guard let image else {
            clearDroppedImage()
            return
        }
        droppedImage = image
    }

    @discardableResult
    func acceptDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url, Self.isImageURL(url), let image = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async {
                        self?.setDroppedImage(image)
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        self?.setDroppedImage(image)
                    }
                }
                return true
            }
        }
        return false
    }

    static func isImageURL(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            let ext = url.pathExtension.lowercased()
            return ["png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp"].contains(ext)
        }
        return type.conforms(to: .image)
    }

    func nudge(_ delta: Double) {
        let next = min(2.5, max(-2.5, ((trackOffset + delta) * 10).rounded() / 10))
        trackOffset = next
        guard !lastKey.isEmpty else { return }
        var stored = UserDefaults.standard.dictionary(forKey: Self.offsetsKey) as? [String: Double] ?? [:]
        if abs(next) < 0.05 {
            stored.removeValue(forKey: lastKey)
        } else {
            stored[lastKey] = next
        }
        UserDefaults.standard.set(stored, forKey: Self.offsetsKey)
    }

    private func loadTrackOffset(for key: String) {
        let stored = UserDefaults.standard.dictionary(forKey: Self.offsetsKey) as? [String: Double] ?? [:]
        trackOffset = stored[key] ?? 0
    }

    var hasTimestamps: Bool {
        lines.contains { $0.time != nil }
    }

    func index(at elapsed: Double, duration: Double) -> Int {
        guard !lines.isEmpty else { return 0 }
        if lines.contains(where: { $0.time != nil }) {
            var current = 0
            for (index, line) in lines.enumerated() {
                if let time = line.time, time <= elapsed {
                    current = index
                }
            }
            return current
        }
        guard duration > 1 else { return 0 }
        let fraction = min(1, max(0, elapsed / duration))
        return min(lines.count - 1, Int(fraction * Double(lines.count)))
    }

    private func fetch(title: String, artist: String, duration: Double) {
        let key = "\(title)|\(artist)"
        guard !title.isEmpty else {
            lastKey = ""
            requestID += 1
            available = false
            isOpen = false
            lines = []
            trackOffset = 0
            return
        }
        guard key != lastKey else { return }
        lastKey = key
        loadTrackOffset(for: key)
        requestID += 1
        let id = requestID
        let keepOpen = isOpen
        available = false
        lines = []

        // Only timed lyrics: Music LRC → lrclib syncedLyrics. No plain / Genius.
        fetchMusicLyrics { [weak self] raw in
            guard let self, id == self.requestID else { return }
            if let music = Self.parse(raw), music.contains(where: { $0.time != nil }) {
                self.apply(music, keepOpen: keepOpen)
                return
            }
            self.fetchCatalogLyrics(title: title, artist: artist, duration: duration) { catalog in
                guard id == self.requestID else { return }
                if let catalog, catalog.contains(where: { $0.time != nil }) {
                    self.apply(catalog, keepOpen: keepOpen)
                } else {
                    self.available = false
                    self.isOpen = false
                    self.lines = []
                }
            }
        }
    }

    private func apply(_ lines: [Line], keepOpen: Bool) {
        self.lines = lines
        available = true
        isOpen = keepOpen
    }

    private func fetchMusicLyrics(done: @escaping (String) -> Void) {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    if player state is stopped then return ""
                    return lyrics of current track
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        runAppleScript(script, completion: done)
    }

    private func fetchCatalogLyrics(
        title: String,
        artist: String,
        duration: Double,
        done: @escaping ([Line]?) -> Void
    ) {
        let cleaned = Self.strippedTitle(title)
        fetchLRCLibGet(title: title, artist: artist, duration: duration) { exact in
            self.searchLRCLib(title: title, artist: artist) { rows in
                var pooled = rows
                if let exact { pooled.insert(exact, at: 0) }
                if let parsed = Self.pickCatalog(pooled, playing: title, artist: artist, duration: duration) {
                    done(parsed)
                    return
                }
                if cleaned != title {
                    self.searchLRCLib(title: cleaned, artist: artist) { extra in
                        var merged = pooled + extra
                        self.fetchLRCLibGet(title: cleaned, artist: artist, duration: duration) { extraExact in
                            if let extraExact { merged.insert(extraExact, at: 0) }
                            done(Self.pickCatalog(merged, playing: title, artist: artist, duration: duration))
                        }
                    }
                } else {
                    done(nil)
                }
            }
        }
    }

    private func fetchLRCLibGet(title: String, artist: String, duration: Double, done: @escaping ([String: Any]?) -> Void) {
        guard duration > 1 else {
            done(nil)
            return
        }
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "duration", value: String(format: "%.2f", duration))
        ]
        let artistName = Self.cleanedArtist(artist)
        if !artistName.isEmpty {
            items.insert(URLQueryItem(name: "artist_name", value: artistName), at: 1)
        }
        components?.queryItems = items
        guard let url = components?.url else {
            done(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Insula (lyrics)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let row = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done(row) }
        }.resume()
    }

    private func searchLRCLib(title: String, artist: String, done: @escaping ([[String: Any]]) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: Self.cleanedArtist(artist))
        ]
        guard let url = components?.url else {
            done([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Insula (lyrics)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let rows = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
            DispatchQueue.main.async { done(rows) }
        }.resume()
    }

    private static func pickCatalog(
        _ rows: [[String: Any]],
        playing: String,
        artist: String,
        duration: Double
    ) -> [Line]? {
        let artistName = cleanedArtist(artist)
        let picked = bestMatch(in: rows, playing: playing, artist: artistName, duration: duration)
            ?? bestMatch(in: rows, playing: playing, artist: "", duration: duration)
        return timedLines(from: picked)
    }

    private static func timedLines(from row: [String: Any]?) -> [Line]? {
        let extra = jsonNumber(row?["offset"])
        let raw = (row?["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let parsed = parse(raw, extraOffset: extra), parsed.contains(where: { $0.time != nil }) else {
            return nil
        }
        return parsed
    }

    private static func jsonNumber(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
    }

    private static let versionTokenPattern =
        #"(?i)\b(super\s+slowed|ultra\s+slowed|slowed(?:\s+down)?(?:\s*\+\s*reverb)?|reverb|sped\s*up|speed\s*up|nightcore|official(?:\s+video)?|lyric(?:s)?(?:\s+video)?|audio|visualizer|remix|bootleg|mashup|cover|live|acoustic|instrumental|remaster(?:ed)?|8d(?:\s+audio)?|1\s*hour|extended|radio\s+edit|clean|explicit|deluxe|snippet|prod\.?|feat\.?|ft\.?)\b"#

    private static func strippedTitle(_ title: String) -> String {
        var cleaned = stripVersionTokens(title)
        if let dash = cleaned.range(of: " - ") {
            let left = String(cleaned[..<dash.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(cleaned[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
            let leftJunk = isVersionJunk(left)
            let rightJunk = isVersionJunk(right)
            if rightJunk, !leftJunk {
                cleaned = left
            } else if leftJunk, !rightJunk {
                cleaned = right
            } else {
                cleaned = left.count >= right.count ? left : right
            }
        }
        return cleaned
    }

    private static func stripVersionTokens(_ title: String) -> String {
        var cleaned = title.replacingOccurrences(
            of: #"[\(\[][^)\]]*[\)\]]"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: versionTokenPattern,
            with: " ",
            options: .regularExpression
        )
        return collapseSpaces(cleaned)
    }

    private static func collapseSpaces(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeForMatch(_ value: String) -> String {
        collapseSpaces(
            value.lowercased()
                .replacingOccurrences(of: #"[“”"'`´]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[&+|,/\\]+"#, with: " ", options: .regularExpression)
        )
    }

    private static func internetTitleMatches(playing: String, candidate: String, artist: String) -> Bool {
        let playRaw = normalizeForMatch(playing)
        let candRaw = normalizeForMatch(candidate)
        guard !candRaw.isEmpty, !playRaw.isEmpty else { return false }
        if playRaw == candRaw { return true }

        var play = playRaw
        let artistFold = normalizeForMatch(cleanedArtist(artist))
        if !artistFold.isEmpty {
            play = stripLeadingArtist(play, artist: artistFold)
            if play == candRaw { return true }
        }

        let playCore = normalizeForMatch(stripVersionTokens(play))
        let candCore = normalizeForMatch(stripVersionTokens(candidate))
        if !playCore.isEmpty, !candCore.isEmpty, playCore == candCore { return true }

        if let leftover = leftover(afterRemoving: candRaw, from: play) ?? leftover(afterRemoving: candCore, from: play) {
            return leftover.isEmpty || isVersionJunk(leftover)
        }
        if !candCore.isEmpty, let leftover = leftover(afterRemoving: candCore, from: playCore) {
            return leftover.isEmpty || isVersionJunk(leftover)
        }
        return false
    }

    private static func stripLeadingArtist(_ title: String, artist: String) -> String {
        let padded = " \(title) "
        let needle = " \(artist) "
        guard let range = padded.range(of: needle) else { return title }
        if range.lowerBound == padded.startIndex || padded.distance(from: padded.startIndex, to: range.lowerBound) <= 1 {
            return collapseSpaces(String(padded[range.upperBound...]))
        }
        return title
    }

    private static func leftover(afterRemoving needle: String, from haystack: String) -> String? {
        guard !needle.isEmpty else { return nil }
        let paddedHay = " \(haystack) "
        let paddedNeedle = " \(needle) "
        guard let range = paddedHay.range(of: paddedNeedle) else { return nil }
        return collapseSpaces(String(paddedHay[..<range.lowerBound]) + String(paddedHay[range.upperBound...]))
    }

    private static func isVersionJunk(_ leftover: String) -> Bool {
        let stripped = stripVersionTokens(leftover)
            .replacingOccurrences(of: #"[-–—:+|/\\.,]"#, with: " ", options: .regularExpression)
        return collapseSpaces(stripped).isEmpty
    }

    private static func cleanedArtist(_ artist: String) -> String {
        let value = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        switch value.lowercased() {
        case "soundcloud", "safari", "chrome":
            return ""
        default:
            return value
        }
    }

    private static func bestMatch(
        in rows: [[String: Any]],
        playing: String,
        artist: String,
        duration: Double
    ) -> [String: Any]? {
        let artistFold = artist.lowercased()
        var best: (score: Int, row: [String: Any])?
        for row in rows {
            let synced = ((row["syncedLyrics"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !synced.isEmpty else { continue }
            let name = row["trackName"] as? String ?? ""
            let user = row["artistName"] as? String ?? ""
            guard internetTitleMatches(playing: playing, candidate: name, artist: artist) else { continue }
            var score = 3
            if normalizeForMatch(name) == normalizeForMatch(playing) { score += 4 }
            if !artistFold.isEmpty {
                let userFold = user.lowercased()
                if userFold.contains(artistFold) || artistFold.contains(userFold) { score += 2 }
            }
            if duration > 1 {
                let trackDuration: Double
                if let number = row["duration"] as? NSNumber {
                    trackDuration = number.doubleValue
                } else if let value = row["duration"] as? Double {
                    trackDuration = value
                } else {
                    trackDuration = 0
                }
                if trackDuration > 1 {
                    let delta = abs(trackDuration - duration)
                    if delta < 2 { score += 6 }
                    else if delta < 5 { score += 2 }
                    else if delta > 12 { score -= 10 }
                }
            }
            score += 5
            score += min(4, synced.count / 400)
            if best == nil || score > best!.score {
                best = (score, row)
            }
        }
        return best?.row
    }

    private static func parse(_ raw: String, extraOffset: Double = 0) -> [Line]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = try? NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]"#)
        var timed: [(Double, String)] = []
        var plain: [String] = []
        var offset: Double = extraOffset

        for line in trimmed.components(separatedBy: .newlines) {
            let value = line.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            if value.hasPrefix("[offset:") {
                let digits = value
                    .dropFirst(8)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                if let milliseconds = Double(digits) {
                    offset += milliseconds / 1000
                }
                continue
            }
            if value.hasPrefix("[ti:") || value.hasPrefix("[ar:") || value.hasPrefix("[al:")
                || value.hasPrefix("[by:") || value.hasPrefix("[length:") {
                continue
            }

            guard let pattern else {
                plain.append(value)
                continue
            }
            let range = NSRange(value.startIndex..., in: value)
            let matches = pattern.matches(in: value, range: range)
            if matches.isEmpty {
                plain.append(value)
                continue
            }
            let textStart = matches.last.flatMap { Range($0.range, in: value) }?.upperBound ?? value.startIndex
            let text = String(value[textStart...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            for match in matches {
                guard
                    let minuteRange = Range(match.range(at: 1), in: value),
                    let secondRange = Range(match.range(at: 2), in: value)
                else { continue }
                let minutes = Double(value[minuteRange]) ?? 0
                let seconds = Double(value[secondRange]) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound, let fracRange = Range(match.range(at: 3), in: value) {
                    let digits = String(value[fracRange])
                    fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
                }
                timed.append((max(0, minutes * 60 + seconds + fraction - offset), text))
            }
        }

        // Callers that need timings discard plain; keep parse general for Music LRC.
        let source = timed.isEmpty
            ? plain.map { (Optional<Double>.none, $0) }
            : timed.sorted { $0.0 < $1.0 }.map { (Optional($0.0), $0.1) }
        let lines = source.enumerated().map { Line(id: $0.offset, time: $0.element.0, text: $0.element.1) }
        return lines.isEmpty ? nil : lines
    }

    private func runAppleScript(_ script: String, completion: @escaping (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        DispatchQueue.global(qos: .utility).async {
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                DispatchQueue.main.async { completion(text) }
            } catch {
                DispatchQueue.main.async { completion("") }
            }
        }
    }
}
