import Combine
import Foundation

final class LyricsManager: ObservableObject {

    struct Line: Identifiable, Equatable {
        let id: Int
        let time: Double?
        let text: String
    }

    @Published var available = false
    @Published var isOpen = false
    @Published var lines: [Line] = []
    @Published var panelSize: CGSize
    @Published var panelOrigin: CGPoint?
    @Published var userPlaced = false
    @Published var isResizing = false
    @Published var trackOffset: Double = 0
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

        fetchMusicLyrics { [weak self] raw in
            guard let self, id == self.requestID else { return }
            let music = Self.parse(raw)
            if let music, music.contains(where: { $0.time != nil }) {
                self.apply(music, keepOpen: keepOpen)
                return
            }
            self.fetchCatalogLyrics(title: title, artist: artist, duration: duration) { catalog in
                guard id == self.requestID else { return }
                if let timed = Self.firstTimed(music, catalog) {
                    self.apply(timed, keepOpen: keepOpen)
                    return
                }
                self.fetchGeniusLyrics(title: title, artist: artist) { genius in
                    guard id == self.requestID else { return }
                    if let best = Self.fullest(music, catalog, genius) {
                        self.apply(best, keepOpen: keepOpen)
                    } else {
                        self.available = false
                        self.isOpen = false
                        self.lines = []
                    }
                }
            }
        }
    }

    private static func firstTimed(_ sources: [Line]?...) -> [Line]? {
        sources.compactMap { $0 }.first { lines in
            lines.contains { $0.time != nil }
        }
    }

    private static func fullest(_ sources: [Line]?...) -> [Line]? {
        sources
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .max { $0.reduce(0) { $0 + $1.text.count } < $1.reduce(0) { $0 + $1.text.count } }
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
                if let parsed = Self.pickCatalog(pooled, playing: title, artist: artist, duration: duration, syncedOnly: true) {
                    done(parsed)
                    return
                }
                if cleaned != title {
                    self.searchLRCLib(title: cleaned, artist: artist) { extra in
                        var merged = pooled + extra
                        self.fetchLRCLibGet(title: cleaned, artist: artist, duration: duration) { extraExact in
                            if let extraExact { merged.insert(extraExact, at: 0) }
                            done(Self.pickCatalog(merged, playing: title, artist: artist, duration: duration, syncedOnly: true)
                                 ?? Self.pickCatalog(merged, playing: title, artist: artist, duration: duration, syncedOnly: false))
                        }
                    }
                } else {
                    done(Self.pickCatalog(pooled, playing: title, artist: artist, duration: duration, syncedOnly: false))
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
        request.setValue("DynamicIslandForMac (lyrics)", forHTTPHeaderField: "User-Agent")
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
        request.setValue("DynamicIslandForMac (lyrics)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let rows = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
            DispatchQueue.main.async { done(rows) }
        }.resume()
    }

    private static func pickCatalog(
        _ rows: [[String: Any]],
        playing: String,
        artist: String,
        duration: Double,
        syncedOnly: Bool
    ) -> [Line]? {
        let artistName = cleanedArtist(artist)
        let picked = bestMatch(in: rows, playing: playing, artist: artistName, duration: duration, syncedOnly: syncedOnly)
            ?? bestMatch(in: rows, playing: playing, artist: "", duration: duration, syncedOnly: syncedOnly)
        return lines(from: picked)
    }

    private static func lines(from row: [String: Any]?) -> [Line]? {
        let extra = jsonNumber(row?["offset"])
        let raw = (row?["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plain = (row?["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return parse(raw ?? "", extraOffset: extra) ?? parse(plain ?? "", extraOffset: extra)
    }

    private static func jsonNumber(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
    }

    private func fetchGeniusLyrics(title: String, artist: String, done: @escaping ([Line]?) -> Void) {
        let queries = Self.geniusQueries(title: title, artist: artist)
        searchGenius(queries: queries, title: title, artist: artist, done: done)
    }

    private func searchGenius(queries: [String], title: String, artist: String, done: @escaping ([Line]?) -> Void) {
        guard let query = queries.first else {
            done(nil)
            return
        }
        let rest = Array(queries.dropFirst())
        let endpoints = [
            "https://genius.com/api/search/song",
            "https://genius.com/api/search"
        ]

        func tryEndpoint(_ index: Int) {
            guard index < endpoints.count, var components = URLComponents(string: endpoints[index]) else {
                searchGenius(queries: rest, title: title, artist: artist, done: done)
                return
            }
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            guard let url = components.url else {
                tryEndpoint(index + 1)
                return
            }
            var request = URLRequest(url: url)
            request.setValue(Self.browserUA, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                if
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let pageURL = Self.bestGeniusURL(in: json, title: title, artist: artist)
                {
                    self?.downloadGeniusPage(pageURL, done: done)
                    return
                }
                tryEndpoint(index + 1)
            }.resume()
        }

        tryEndpoint(0)
    }

    private func downloadGeniusPage(_ pageURL: URL, done: @escaping ([Line]?) -> Void) {
        var request = URLRequest(url: pageURL)
        request.setValue(Self.browserUA, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let html = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let parsed = Self.parse(Self.geniusLyrics(from: html) ?? "")
            DispatchQueue.main.async { done(parsed) }
        }.resume()
    }

    private static let browserUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

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

    /// Internet lyrics only on an exact title, or when the catalog/Genius title
    /// is fully present in the playing title (extra prefixes like "slowed").
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

    private static func geniusQuery(title: String, artist: String) -> String {
        let cleanedTitle = strippedTitle(title)
        let artistName = cleanedArtist(artist)
        if artistName.isEmpty {
            return cleanedTitle
        }
        return "\(artistName) \(cleanedTitle)"
    }

    private static func geniusQueries(title: String, artist: String) -> [String] {
        var queries: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !trimmed.isEmpty, seen.insert(key).inserted else { return }
            queries.append(trimmed)
        }

        add(geniusQuery(title: title, artist: artist))
        add(strippedTitle(title))
        add(title)

        let artistName = cleanedArtist(artist)
        if !artistName.isEmpty {
            add("\(artistName) \(strippedTitle(title))")
        }

        let parts = title.components(separatedBy: " - ")
        if parts.count >= 2 {
            if !isVersionJunk(parts[0]) { add(parts[0]) }
            let rest = parts.dropFirst().joined(separator: " ")
            if !isVersionJunk(rest) { add(rest) }
        }

        return queries
    }

    private static func bestGeniusURL(in json: [String: Any], title: String, artist: String) -> URL? {
        let response = json["response"] as? [String: Any] ?? [:]
        let sectionHits = (response["sections"] as? [[String: Any]] ?? [])
            .flatMap { $0["hits"] as? [[String: Any]] ?? [] }
        let hits = (response["hits"] as? [[String: Any]]) ?? sectionHits
        let artistFold = normalizeForMatch(cleanedArtist(artist))
        var best: (score: Int, url: String)?
        for hit in hits {
            guard let result = hit["result"] as? [String: Any] else { continue }
            let name = result["title"] as? String ?? ""
            let user = (result["primary_artist"] as? [String: Any])?["name"] as? String ?? ""
            let url = result["url"] as? String ?? ""
            guard !url.isEmpty else { continue }
            guard internetTitleMatches(playing: title, candidate: name, artist: artist) else { continue }
            var score = 4
            if normalizeForMatch(name) == normalizeForMatch(title)
                || normalizeForMatch(stripVersionTokens(name)) == normalizeForMatch(stripVersionTokens(title)) {
                score += 4
            }
            let userFold = normalizeForMatch(user)
            if !artistFold.isEmpty, userFold.contains(artistFold) || artistFold.contains(userFold) {
                score += 3
            }
            if best == nil || score > best!.score {
                best = (score, url)
            }
        }
        guard let url = best?.url else { return nil }
        return URL(string: url)
    }

    private static func geniusLyrics(from html: String) -> String? {
        let cleaned = removeExcludedDivs(html)
        let containers = extractDivs(in: cleaned, marker: #"data-lyrics-container="true""#)
        var parts: [String] = []
        for container in containers {
            let text = htmlToLyricsText(container)
            if !text.isEmpty { parts.append(text) }
        }
        let joined = parts.joined(separator: "\n")
        if joined.isEmpty || joined.localizedCaseInsensitiveContains("lyrics for this song have yet to be released") {
            return nil
        }
        return joined
    }

    private static func removeExcludedDivs(_ html: String) -> String {
        let ns = NSMutableString(string: html)
        while true {
            let marker = ns.range(of: #"data-exclude-from-selection="true""#)
            if marker.location == NSNotFound { break }
            let tagSearch = ns.range(of: "<div", options: .backwards, range: NSRange(location: 0, length: marker.location))
            if tagSearch.location == NSNotFound { break }
            guard let end = endOfDivSubtree(ns, tagStart: tagSearch.location) else { break }
            ns.replaceCharacters(in: NSRange(location: tagSearch.location, length: end - tagSearch.location), with: "")
        }
        return ns as String
    }

    private static func extractDivs(in html: String, marker: String) -> [String] {
        let ns = html as NSString
        var parts: [String] = []
        var start = 0
        let length = ns.length
        while start < length {
            let idx = ns.range(of: marker, options: [], range: NSRange(location: start, length: length - start))
            if idx.location == NSNotFound { break }
            let tagSearch = ns.range(of: "<div", options: .backwards, range: NSRange(location: 0, length: idx.location))
            if tagSearch.location != NSNotFound, let end = endOfDivSubtree(ns, tagStart: tagSearch.location) {
                parts.append(ns.substring(with: NSRange(location: tagSearch.location, length: end - tagSearch.location)))
            }
            start = idx.location + max(idx.length, 1)
        }
        return parts
    }

    private static func endOfDivSubtree(_ ns: NSString, tagStart: Int) -> Int? {
        var depth = 0
        var pos = tagStart
        let length = ns.length
        while pos < length {
            let remaining = length - pos
            let next = ns.range(of: "<", options: [], range: NSRange(location: pos, length: remaining))
            if next.location == NSNotFound { return nil }
            pos = next.location
            if pos + 4 <= length, ns.substring(with: NSRange(location: pos, length: 4)).lowercased() == "<div" {
                depth += 1
                pos += 4
            } else if pos + 6 <= length, ns.substring(with: NSRange(location: pos, length: 6)).lowercased() == "</div>" {
                depth -= 1
                pos += 6
                if depth == 0 { return pos }
            } else {
                pos += 1
            }
        }
        return nil
    }

    private static func htmlToLyricsText(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</div>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                let lower = line.lowercased()
                if lower.contains("you might also like") { return false }
                if lower.contains("contributors") { return false }
                if lower.hasSuffix("embed"), line.count < 18 { return false }
                return true
            }
        return lines.joined(separator: "\n")
    }

    private static func bestMatch(
        in rows: [[String: Any]],
        playing: String,
        artist: String,
        duration: Double,
        syncedOnly: Bool
    ) -> [String: Any]? {
        let artistFold = artist.lowercased()
        var best: (score: Int, row: [String: Any])?
        for row in rows {
            let synced = ((row["syncedLyrics"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let plain = ((row["plainLyrics"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if syncedOnly, synced.isEmpty { continue }
            let hasText = !synced.isEmpty || !plain.isEmpty
            guard hasText else { continue }
            let name = row["trackName"] as? String ?? ""
            let user = (row["artistName"] as? String ?? "")
            guard internetTitleMatches(playing: playing, candidate: name, artist: artist) else { continue }
            var score = 3
            if normalizeForMatch(name) == normalizeForMatch(playing) { score += 4 }
            if !artistFold.isEmpty {
                let userFold = user.lowercased()
                if userFold.contains(artistFold) || artistFold.contains(userFold) { score += 2 }
            }
            if syncedOnly, duration > 1 {
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
            if !synced.isEmpty { score += 5 }
            score += min(4, (synced.isEmpty ? plain : synced).count / 400)
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
