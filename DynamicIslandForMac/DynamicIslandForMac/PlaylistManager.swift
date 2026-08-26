import Combine
import Foundation

final class PlaylistManager: ObservableObject {

    struct Track: Identifiable, Equatable {
        let id: Int
        let index: Int
        let name: String
        let artist: String
    }

    @Published var available = false
    @Published var isOpen = false
    @Published var playlistName = ""
    @Published var tracks: [Track] = []
    @Published var currentIndex = 0
    @Published var panelSize: CGSize
    @Published var panelOrigin: CGPoint?
    @Published var userPlaced = false
    @Published var isResizing = false
    var pinnedLeft: CGFloat = 0
    var pinnedTop: CGFloat = 0
    var onLiveFrame: (() -> Void)?

    static let defaultPanelSize = CGSize(width: 300, height: 220)
    static let minPanelSize = CGSize(width: 240, height: 120)
    static let maxPanelSize = CGSize(width: 420, height: 480)

    private var requestID = 0
    private var bag = Set<AnyCancellable>()
    private static let widthKey = "playlist.panel.w"
    private static let heightKey = "playlist.panel.h"
    private static let xKey = "playlist.panel.x"
    private static let yKey = "playlist.panel.y"
    private static let placedKey = "playlist.panel.placed"

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

    func start(nowPlaying: NowPlayingManager) {
        nowPlaying.$title
            .combineLatest(nowPlaying.$artist, nowPlaying.$appName, nowPlaying.$isPlaying)
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _, _, appName, _ in
                self?.fetch(appName: appName)
            }
            .store(in: &bag)
    }

    func toggle() {
        guard available else { return }
        isOpen.toggle()
        if isOpen {
            fetch(appName: "Music")
        }
    }

    func play(_ track: Track) {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    play track \(track.index) of current playlist
                end try
            end tell
        end if
        """
        runAppleScript(script) { _ in }
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

    private func fetch(appName: String) {
        let lower = appName.lowercased()
        let isMusic = lower.contains("music") || lower.contains("музык") || lower.contains("itunes")
        guard isMusic else {
            available = false
            if isOpen { isOpen = false }
            tracks = []
            playlistName = ""
            return
        }

        requestID += 1
        let id = requestID
        runAppleScript(Self.fetchScript) { [weak self] output in
            guard let self, id == self.requestID else { return }
            self.apply(output)
        }
    }

    private func apply(_ output: String) {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else {
            available = false
            if isOpen { isOpen = false }
            return
        }
        let head = header.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard head.first == "YES", head.count >= 3 else {
            available = false
            if isOpen { isOpen = false }
            tracks = []
            playlistName = ""
            return
        }

        playlistName = head[1]
        currentIndex = Int(head[2]) ?? 0
        let kind = head.count >= 4 ? head[3].lowercased() : ""
        let deniedKinds = ["library", "folder", "radio", "podcast", "podcasts", "audiobook", "audiobooks", "purchased", "purchased music", "music"]
        let deniedNames = ["library", "медиатека", "biblioteca", "bibliothèque"]
        if deniedKinds.contains(kind) || deniedNames.contains(playlistName.lowercased()) {
            available = false
            if isOpen { isOpen = false }
            tracks = []
            playlistName = ""
            return
        }
        tracks = lines.dropFirst().enumerated().compactMap { offset, line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3, let index = Int(parts[0]) else { return nil }
            return Track(id: offset, index: index, name: parts[1], artist: parts[2])
        }
        available = !tracks.isEmpty
        if !available, isOpen { isOpen = false }
    }

    private static let fetchScript = """
    if application "Music" is running then
        tell application "Music"
            try
                if player state is stopped then return "NO"
                set pl to current playlist
                set kindText to ""
                try
                    set kindText to special kind of pl as text
                end try
                set plName to name of pl
                if kindText is "library" or kindText is "folder" or kindText is "radio" or kindText is "podcast" or kindText is "podcasts" or kindText is "audiobook" or kindText is "audiobooks" or kindText is "purchased" or kindText is "purchased music" or kindText is "Music" then return "NO"
                if plName is "Library" or plName is "Медиатека" then return "NO"
                set total to count of tracks of pl
                if total is 0 then return "NO"
                set idx to 1
                try
                    set idx to index of current track
                end try
                set fromIdx to idx - 15
                if fromIdx < 1 then set fromIdx to 1
                set toIdx to fromIdx + 59
                if toIdx > total then set toIdx to total
                set out to "YES" & tab & plName & tab & (idx as text) & tab & kindText & linefeed
                repeat with i from fromIdx to toIdx
                    set t to track i of pl
                    set tName to name of t
                    set tArtist to ""
                    try
                        set tArtist to artist of t
                    end try
                    set out to out & (i as text) & tab & tName & tab & tArtist & linefeed
                end repeat
                return out
            on error
                return "NO"
            end try
        end tell
    else
        return "NO"
    end if
    """

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
