import Cocoa
import Combine
import ImageIO

final class NowPlayingManager: ObservableObject {

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var appName: String = ""
    @Published var isPlaying: Bool = false
    @Published var artwork: NSImage?
    @Published var duration: Double = 0
    @Published var displayedElapsed: Double = 0

    private var elapsedAtLastFetch: Double = 0
    private var fetchedAt: Date = Date()
    private var isScrubbing = false
    private var holdElapsedUntil: Date?
    private var pausedPolls = 0

    private var fallbackPollTimer: Timer?
    private var musicPollTimer: Timer?
    private var lastTrackKey: String?
    private var lastHelperLine: String?
    private var musicIsSource = false
    private var artworkRequestID = 0
    private var soundCloudClientID: String?

    private var helper: Process?
    private var helperPipe: Pipe?
    private var helperBuffer = Data()
    private var helperShouldRun = false
    private var helperFailures = 0
    private var useFallbackPolling = false
    private let helperQueue = DispatchQueue(label: "nowplaying.helper")

    private typealias SendCommandFn = @convention(c) (Int, [String: Any]?) -> Bool
    private typealias SetElapsedTimeFn = @convention(c) (Double) -> Void

    private var sendCommandFn: SendCommandFn?
    private var setElapsedTimeFn: SetElapsedTimeFn?

    private static let helperScript = """
    var MRNowPlayingRequest = null;

    function snapshot() {
      try {
        const item = MRNowPlayingRequest.localNowPlayingItem;
        const infoDict = item.nowPlayingInfo;
        const appNameObj = MRNowPlayingRequest.localNowPlayingPlayerPath.client.displayName;
        function str(key) {
          const v = infoDict.valueForKey(key);
          return (v && v.js !== undefined) ? v.js : "";
        }
        function num(key) {
          const v = infoDict.valueForKey(key);
          return (v && v.js !== undefined) ? v.js : 0;
        }
        function artworkURL() {
          const keys = ['kMRMediaRemoteNowPlayingInfoArtworkURL','artworkURL','artworkUrl','artwork_url'];
          for (let i = 0; i < keys.length; i++) {
            let s = String(str(keys[i]) || "").trim();
            if (s.indexOf("//") === 0) s = "https:" + s;
            if (s.indexOf("http") === 0) return s;
          }
          return "";
        }
        function isVideo() {
          const keys = ['kMRMediaRemoteNowPlayingInfoMediaType','MPNowPlayingInfoPropertyMediaType'];
          for (let i = 0; i < keys.length; i++) {
            if (num(keys[i]) === 2) return 1;
            const s = String(str(keys[i]) || "").toLowerCase();
            if (s.indexOf('video') !== -1) return 1;
          }
          if (num('kMRMediaRemoteNowPlayingInfoIsVideo') === 1) return 1;
          return 0;
        }
        let bundleID = "";
        try {
          const bundleObj = MRNowPlayingRequest.localNowPlayingPlayerPath.client.bundleIdentifier;
          bundleID = (bundleObj && bundleObj.js !== undefined) ? String(bundleObj.js) : "";
        } catch (e) {}
        return JSON.stringify({
          title: str('kMRMediaRemoteNowPlayingInfoTitle'),
          artist: str('kMRMediaRemoteNowPlayingInfoArtist'),
          album: str('kMRMediaRemoteNowPlayingInfoAlbum'),
          playbackRate: num('kMRMediaRemoteNowPlayingInfoPlaybackRate'),
          elapsed: num('kMRMediaRemoteNowPlayingInfoElapsedTime'),
          duration: num('kMRMediaRemoteNowPlayingInfoDuration'),
          appName: (appNameObj && appNameObj.js !== undefined) ? appNameObj.js : "",
          bundleID: bundleID,
          artworkURL: artworkURL(),
          isVideo: isVideo()
        });
      } catch (e) {
        return JSON.stringify({title: "", artist: "", album: "", playbackRate: 0, elapsed: 0, duration: 0, appName: "", bundleID: "", artworkURL: "", isVideo: 0});
      }
    }

    function emit() {
      const line = snapshot() + "\\n";
      const ns = $.NSString.alloc.initWithUTF8String(line);
      $.NSFileHandle.fileHandleWithStandardOutput.writeData(ns.dataUsingEncoding($.NSUTF8StringEncoding));
    }

    function run() {
      ObjC.import('Foundation');
      const MediaRemote = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
      MediaRemote.load;
      MRNowPlayingRequest = $.NSClassFromString('MRNowPlayingRequest');
        while (true) {
        emit();
        delay(2.0);
      }
    }
    """

    private static let oneShotScript = """
    function run() {
      try {
        const MediaRemote = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
        MediaRemote.load;
        const MRNowPlayingRequest = $.NSClassFromString('MRNowPlayingRequest');
        const item = MRNowPlayingRequest.localNowPlayingItem;
        const infoDict = item.nowPlayingInfo;
        const appNameObj = MRNowPlayingRequest.localNowPlayingPlayerPath.client.displayName;
        function str(key) {
          const v = infoDict.valueForKey(key);
          return (v && v.js !== undefined) ? v.js : "";
        }
        function num(key) {
          const v = infoDict.valueForKey(key);
          return (v && v.js !== undefined) ? v.js : 0;
        }
        function artworkURL() {
          const keys = ['kMRMediaRemoteNowPlayingInfoArtworkURL','artworkURL','artworkUrl','artwork_url'];
          for (let i = 0; i < keys.length; i++) {
            let s = String(str(keys[i]) || "").trim();
            if (s.indexOf("//") === 0) s = "https:" + s;
            if (s.indexOf("http") === 0) return s;
          }
        return "";
        }
        function isVideo() {
          const keys = ['kMRMediaRemoteNowPlayingInfoMediaType','MPNowPlayingInfoPropertyMediaType'];
          for (let i = 0; i < keys.length; i++) {
            if (num(keys[i]) === 2) return 1;
            const s = String(str(keys[i]) || "").toLowerCase();
            if (s.indexOf('video') !== -1) return 1;
          }
          if (num('kMRMediaRemoteNowPlayingInfoIsVideo') === 1) return 1;
          return 0;
        }
        let bundleID = "";
        try {
          const bundleObj = MRNowPlayingRequest.localNowPlayingPlayerPath.client.bundleIdentifier;
          bundleID = (bundleObj && bundleObj.js !== undefined) ? String(bundleObj.js) : "";
        } catch (e) {}
        return JSON.stringify({
          title: str('kMRMediaRemoteNowPlayingInfoTitle'),
          artist: str('kMRMediaRemoteNowPlayingInfoArtist'),
          album: str('kMRMediaRemoteNowPlayingInfoAlbum'),
          playbackRate: num('kMRMediaRemoteNowPlayingInfoPlaybackRate'),
          elapsed: num('kMRMediaRemoteNowPlayingInfoElapsedTime'),
          duration: num('kMRMediaRemoteNowPlayingInfoDuration'),
          appName: (appNameObj && appNameObj.js !== undefined) ? appNameObj.js : "",
          bundleID: bundleID,
          artworkURL: artworkURL(),
          isVideo: isVideo()
        });
      } catch (e) {
        return JSON.stringify({title: "", artist: "", album: "", playbackRate: 0, elapsed: 0, duration: 0, appName: "", bundleID: "", artworkURL: "", isVideo: 0});
      }
    }
    """

    init() {
        loadCommandFunctions()
        startHelper()
        startMusicPoll()
    }

    deinit {
        shutdown()
    }

    func shutdown() {
        stopHelper()
        fallbackPollTimer?.invalidate()
        fallbackPollTimer = nil
        musicPollTimer?.invalidate()
        musicPollTimer = nil
    }

    private func loadCommandFunctions() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else { return }

        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommandFn = unsafeBitCast(sym, to: SendCommandFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            setElapsedTimeFn = unsafeBitCast(sym, to: SetElapsedTimeFn.self)
        }
    }

    private func startHelper() {
        stopHelper()
        helperShouldRun = true
        helperBuffer = Data()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", Self.helperScript]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.helperDidExit(proc)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.helperQueue.async {
                self?.consumeHelperData(data)
            }
        }

        do {
            try process.run()
            helper = process
            helperPipe = pipe
        } catch {
            startFallbackPolling()
        }
    }

    private func stopHelper() {
        helperShouldRun = false
        helperPipe?.fileHandleForReading.readabilityHandler = nil
        helper?.terminationHandler = nil
        if let helper, helper.isRunning {
            helper.terminate()
        }
        helper = nil
        helperPipe = nil
    }

    private func helperDidExit(_ proc: Process) {
        guard helperShouldRun, helper === proc else { return }
        helper = nil
        helperPipe?.fileHandleForReading.readabilityHandler = nil
        helperPipe = nil
        helperFailures += 1
        if helperFailures >= 3 {
            startFallbackPolling()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.helperShouldRun, !self.useFallbackPolling else { return }
            self.startHelper()
        }
    }

    private func consumeHelperData(_ data: Data) {
        helperBuffer.append(data)
        while let newline = helperBuffer.firstIndex(of: 0x0A) {
            let line = helperBuffer.subdata(in: helperBuffer.startIndex..<newline)
            helperBuffer.removeSubrange(..<helperBuffer.index(after: newline))
            guard let text = String(data: line, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { continue }
            DispatchQueue.main.async { [weak self] in
                self?.applyPayload(text)
            }
        }
    }

    private func startFallbackPolling() {
        useFallbackPolling = true
        stopHelper()
        fallbackPollTimer?.invalidate()
        fallbackPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshOneShot()
        }
        refreshOneShot()
    }

    func elapsed(at date: Date = Date()) -> Double {
        if isScrubbing { return displayedElapsed }
        let extra = isPlaying ? date.timeIntervalSince(fetchedAt) : 0
        let value = elapsedAtLastFetch + extra
        if duration > 1 {
            return min(max(0, value), duration)
        }
        return max(0, value)
    }

    func beginScrub(to seconds: Double) {
        isScrubbing = true
        displayedElapsed = clamped(seconds)
    }

    func refresh() {
        if useFallbackPolling {
            refreshOneShot()
        }
        pollMusicApp()
    }

    private func startMusicPoll() {
        musicPollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.4, repeats: true) { [weak self] _ in
            self?.pollMusicApp()
        }
        timer.tolerance = 0.4
        RunLoop.main.add(timer, forMode: .common)
        musicPollTimer = timer
        pollMusicApp()
    }

    private func pollMusicApp() {
        let musicRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.Music")
            .isEmpty
        if !musicRunning {
            musicIsSource = false
            return
        }

        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    if player state is stopped then return ""
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to ""
                    try
                        set trackAlbum to album of current track
                    end try
                    set trackId to ""
                    try
                        set trackId to persistent ID of current track as text
                    end try
                    set trackDur to 0
                    try
                        set trackDur to duration of current track
                    end try
                    set trackPos to 0
                    try
                        set trackPos to player position
                    end try
                    set trackTime to ""
                    try
                        set trackTime to time of current track as text
                    end try
                    set isPlay to player state is playing
                    return trackName & tab & trackArtist & tab & (trackDur as text) & tab & (trackPos as text) & tab & (isPlay as text) & tab & trackTime & tab & trackAlbum & tab & trackId
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        runAppleScript(script) { [weak self] output in
            self?.applyMusicLine(output)
        }
    }

    private func applyMusicLine(_ output: String) {
        let parts = output.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 5 else {
            musicIsSource = false
            return
        }

        let newTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let newArtist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        var dur = parseMusicNumber(parts[2])
        if parts.count >= 6 {
            let clock = parseClock(parts[5])
            if clock > 1, dur <= 1 || (dur < 30 && clock > dur * 5) {
                dur = clock
            }
        }
        let elapsed = parseMusicNumber(parts[3])
        let playing = parts[4].lowercased().contains("true")
        guard !newTitle.isEmpty else {
            musicIsSource = false
            return
        }

        let remoteIsOtherApp = !appName.isEmpty
            && !musicIsSource
            && !appName.lowercased().contains("music")
            && !appName.lowercased().contains("музык")
            && !appName.lowercased().contains("itunes")
        if remoteIsOtherApp { return }

        if dur > 0, dur < Self.musicMinDuration { return }

        musicIsSource = true

        if title != newTitle { title = newTitle }
        if artist != newArtist { artist = newArtist }
        if appName != "Music" { appName = "Music" }

        if dur > 1 { duration = dur }

        applyPlaybackState(playing)

        let album = parts.count >= 7 ? parts[6] : ""
        let trackID = parts.count >= 8 ? parts[7] : ""
        let key = "\(newTitle)|\(newArtist)|\(album)|\(trackID)|Music"
        let trackChanged = key != lastTrackKey
        applyElapsed(elapsed, playing: playing, trackChanged: trackChanged)
        if trackChanged {
            lastTrackKey = key
            artwork = nil
            fetchArtwork(appName: "Music")
        }
    }

    private func parseMusicNumber(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(trimmed) { return value }
        return Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func parseClock(_ raw: String) -> Double {
        let bits = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
            .compactMap { parseMusicNumber(String($0)) }
        if bits.count == 3 { return bits[0] * 3600 + bits[1] * 60 + bits[2] }
        if bits.count == 2 { return bits[0] * 60 + bits[1] }
        return 0
    }

    private func refreshOneShot() {
        runProcess(
            executable: "/usr/bin/osascript",
            arguments: ["-l", "JavaScript", "-e", Self.oneShotScript]
        ) { [weak self] output in
            self?.applyPayload(output)
        }
    }

    private func applyPayload(_ output: String) {
            if output == lastHelperLine { return }
            guard
                let data = output.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            lastHelperLine = output

        helperFailures = 0

            let newTitle = json["title"] as? String ?? ""
            let newArtist = json["artist"] as? String ?? ""
        let rate = Self.jsonNumber(json["playbackRate"])
        let elapsed = Self.jsonNumber(json["elapsed"])
        let dur = Self.jsonNumber(json["duration"])
        var appName = json["appName"] as? String ?? ""
        let bundleID = json["bundleID"] as? String ?? ""
        if !appName.localizedCaseInsensitiveContains("soundcloud"),
           bundleID.localizedCaseInsensitiveContains("soundcloud") {
            appName = "SoundCloud"
        }
        if !Self.shouldShowNowPlaying(
            appName: appName,
            bundleID: bundleID,
            duration: dur,
            isVideo: Self.jsonNumber(json["isVideo"]) > 0
        ) {
            if musicIsSource { return }
            if Self.isMessenger(appName: self.appName, bundleID: "")
                || (!self.appName.isEmpty && self.appName.caseInsensitiveCompare(appName) == .orderedSame) {
                clearIdleState()
            }
            return
        }
        let remoteArtURL = json["artworkURL"] as? String ?? ""
        let playing = rate > 0.05

        if newTitle.isEmpty {
            if musicIsSource { return }
            clearIdleState()
            return
        }

        if musicIsSource {
            let lower = appName.lowercased()
            let otherApp = !appName.isEmpty
                && !lower.contains("music")
                && !lower.contains("музык")
                && !lower.contains("itunes")
            if !otherApp {
                if dur > 1, duration <= 1 || (duration < 40 && dur > 60) {
                    duration = dur
                }
                if newTitle != title || newArtist != artist {
                    title = newTitle
                    artist = newArtist
                    lastTrackKey = nil
                    artwork = nil
                    fetchArtwork(appName: "Music")
                }
                applyPlaybackState(playing)
                applyElapsed(elapsed, playing: playing, trackChanged: false)
                return
            }
            musicIsSource = false
        }

        if title != newTitle { title = newTitle }
        if artist != newArtist { artist = newArtist }
        if !appName.isEmpty, self.appName != appName { self.appName = appName }

        let album = json["album"] as? String ?? ""
        let key = "\(newTitle)|\(newArtist)|\(album)|\(appName.isEmpty ? self.appName : appName)"
        let trackChanged = key != lastTrackKey
        if dur > 1 {
            duration = dur
        } else if trackChanged, duration <= 1 {
            duration = 0
        }

        applyPlaybackState(playing)
        applyElapsed(elapsed, playing: playing, trackChanged: trackChanged)

        if trackChanged {
            lastTrackKey = key
            artwork = nil
            fetchArtwork(appName: appName.isEmpty ? self.appName : appName)
        } else if artwork == nil, Self.isArtworkURL(remoteArtURL) {
            downloadArtwork(from: remoteArtURL, requestID: artworkRequestID)
        }
    }

    private static func jsonNumber(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
    }

    private enum ArtworkSource {
        case spotify
        case music
        case soundcloud
        case none
    }

    private func artworkSource(for appName: String) -> ArtworkSource {
        let lower = appName.lowercased()
        if lower.contains("spotify") { return .spotify }
        if lower.contains("soundcloud") { return .soundcloud }
        if musicIsSource
            || lower.contains("music")
            || lower.contains("музыка")
            || lower.contains("itunes") {
            return .music
        }
        return .none
    }

    private func fetchArtwork(appName: String) {
        artworkRequestID += 1
        let requestID = artworkRequestID

        switch artworkSource(for: appName) {
        case .spotify:
            fetchSpotifyArtwork(requestID: requestID)
        case .music:
            fetchMusicAppArtwork(retriesLeft: 3, requestID: requestID)
        case .soundcloud:
            fetchSoundCloudSearchArtwork(requestID: requestID, requireMatch: false)
            fetchSoundCloudArtwork(requestID: requestID, attemptsLeft: 4)
        case .none:
            if Self.looksLikeBrowser(appName) {
                fetchSoundCloudSearchArtwork(requestID: requestID, requireMatch: true)
            }
            fetchMediaRemoteArtwork(requestID: requestID)
        }
    }

    private func clearIdleState() {
        guard !title.isEmpty || artwork != nil || duration > 0 else { return }
        title = ""
        artist = ""
        appName = ""
        duration = 0
        displayedElapsed = 0
        elapsedAtLastFetch = 0
        isPlaying = false
        lastTrackKey = nil
        artworkRequestID += 1
        artwork = nil
    }

    private func fetchMusicAppArtwork(retriesLeft: Int, requestID: Int) {
        let path = NSTemporaryDirectory() + "dynamic_island_artwork_\(UUID().uuidString).bin"
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    if not (exists current track) then return ""
                    if (count of artworks of current track) is 0 then return ""
                    try
                        set artData to raw data of artwork 1 of current track
                    on error
                        set artData to data of artwork 1 of current track
                    end try
                on error
                    return ""
                end try
            end tell
            try
                set outPath to "\(escaped)"
                set fileRef to open for access (POSIX file outPath) with write permission
                set eof of fileRef to 0
                write artData to fileRef
                close access fileRef
                return outPath
            on error
                try
                    close access POSIX file "\(escaped)"
                end try
                return ""
            end try
        else
            return ""
        end if
        """

        runAppleScript(script) { [weak self] output in
            guard let self, requestID == self.artworkRequestID else {
                try? FileManager.default.removeItem(atPath: path)
                return
            }

            if !output.isEmpty, let image = Self.image(fromFile: output) {
                self.artwork = image
                try? FileManager.default.removeItem(atPath: output)
                return
            }

            try? FileManager.default.removeItem(atPath: path)
            self.fetchMediaRemoteArtwork(requestID: requestID)

            if retriesLeft > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self, requestID == self.artworkRequestID else { return }
                    self.fetchMusicAppArtwork(retriesLeft: retriesLeft - 1, requestID: requestID)
                }
            } else if self.artwork == nil {
                self.fetchCatalogArtwork(requestID: requestID)
            }
        }
    }

    private func fetchMediaRemoteArtwork(requestID: Int) {
        let path = NSTemporaryDirectory() + "dynamic_island_mr_\(UUID().uuidString).bin"
        runProcess(
            executable: "/usr/bin/osascript",
            arguments: ["-l", "JavaScript", "-e", Self.mediaRemoteArtworkScript(dumpPath: path)]
        ) { [weak self] output in
            guard let self, requestID == self.artworkRequestID else {
                try? FileManager.default.removeItem(atPath: path)
                return
            }
            if Self.isArtworkURL(output) {
                self.downloadArtwork(from: output, requestID: requestID) {
                    self.fetchSoundCloudSearchArtwork(requestID: requestID, requireMatch: true) {
                        self.fetchCatalogArtwork(requestID: requestID)
                    }
                }
            } else if !output.isEmpty, let image = Self.image(fromFile: output) {
                self.artwork = image
            } else if self.artwork == nil {
                self.fetchSoundCloudSearchArtwork(requestID: requestID, requireMatch: true) {
                    self.fetchCatalogArtwork(requestID: requestID)
                }
            }
            if !Self.isArtworkURL(output) {
                try? FileManager.default.removeItem(atPath: output.isEmpty ? path : output)
        } else {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    private func fetchSoundCloudArtwork(requestID: Int, attemptsLeft: Int) {
        fetchMediaRemoteArtworkOnly(requestID: requestID) { [weak self] got in
            guard let self, requestID == self.artworkRequestID else { return }
            if got || self.artwork != nil { return }
            if attemptsLeft > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self, requestID == self.artworkRequestID else { return }
                    self.fetchSoundCloudArtwork(requestID: requestID, attemptsLeft: attemptsLeft - 1)
                }
                return
            }
            self.fetchSoundCloudSearchArtwork(requestID: requestID, requireMatch: false) {
                self.fetchDeezerArtwork(requestID: requestID) {
                    self.fetchCatalogArtwork(requestID: requestID)
                }
            }
        }
    }

    private func fetchMediaRemoteArtworkOnly(requestID: Int, done: @escaping (Bool) -> Void) {
        let path = NSTemporaryDirectory() + "dynamic_island_mr_\(UUID().uuidString).bin"
        runProcess(
            executable: "/usr/bin/osascript",
            arguments: ["-l", "JavaScript", "-e", Self.mediaRemoteArtworkScript(dumpPath: path)]
        ) { [weak self] output in
            guard let self, requestID == self.artworkRequestID else {
                try? FileManager.default.removeItem(atPath: path)
                done(false)
                return
            }
            if Self.isArtworkURL(output) {
                try? FileManager.default.removeItem(atPath: path)
                self.downloadArtwork(from: output, requestID: requestID) {
                    done(self.artwork != nil)
                }
                return
            }
            if !output.isEmpty, let image = Self.image(fromFile: output) {
            self.artwork = image
            try? FileManager.default.removeItem(atPath: output)
                done(true)
                return
            }
            try? FileManager.default.removeItem(atPath: output.isEmpty ? path : output)
            done(false)
        }
    }

    private func fetchDeezerArtwork(requestID: Int, then: @escaping () -> Void) {
        guard artwork == nil else { then(); return }
        let term = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
        guard !term.isEmpty else { then(); return }

        var components = URLComponents(string: "https://api.deezer.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: term), URLQueryItem(name: "limit", value: "1")]
        guard let url = components?.url else { then(); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["data"] as? [[String: Any]],
                let first = results.first,
                let album = first["album"] as? [String: Any],
                let raw = (album["cover_medium"] as? String) ?? (album["cover"] as? String),
                let artURL = URL(string: raw)
            else {
                DispatchQueue.main.async { then() }
                return
            }
            self.downloadArtwork(from: artURL, requestID: requestID, then: then)
        }.resume()
    }

    private func fetchSoundCloudSearchArtwork(requestID: Int, requireMatch: Bool, then: (() -> Void)? = nil) {
        guard artwork == nil else { then?(); return }
        let term = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
        guard !term.isEmpty else { then?(); return }

        resolveSoundCloudClientID { [weak self] clientID in
            guard let self, requestID == self.artworkRequestID else { return }
            guard let clientID else { then?(); return }
            self.searchSoundCloudAPI(
                term: term,
                clientID: clientID,
                requestID: requestID,
                requireMatch: requireMatch,
                then: then
            )
        }
    }

    private func resolveSoundCloudClientID(then: @escaping (String?) -> Void) {
        if let soundCloudClientID {
            then(soundCloudClientID)
            return
        }

        var request = URLRequest(url: URL(string: "https://soundcloud.com")!)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { then(nil) }
                return
            }
            if let id = Self.soundCloudClientID(in: html) {
                DispatchQueue.main.async {
                    self.soundCloudClientID = id
                    then(id)
                }
                return
            }

            let scripts = Self.soundCloudScriptURLs(in: html)
            guard !scripts.isEmpty else {
                DispatchQueue.main.async { then(nil) }
                return
            }

            let group = DispatchGroup()
            let lock = NSLock()
            var found: String?
            for url in scripts {
                group.enter()
                var scriptRequest = URLRequest(url: url)
                scriptRequest.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
                URLSession.shared.dataTask(with: scriptRequest) { data, _, _ in
                    defer { group.leave() }
                    lock.lock()
                    let already = found != nil
                    lock.unlock()
                    guard !already, let data, let text = String(data: data, encoding: .utf8) else { return }
                    guard let id = Self.soundCloudClientID(in: text) else { return }
                    lock.lock()
                    if found == nil { found = id }
                    lock.unlock()
                }.resume()
            }
            group.notify(queue: .main) { [weak self] in
                self?.soundCloudClientID = found
                then(found)
            }
        }.resume()
    }

    private func searchSoundCloudAPI(
        term: String,
        clientID: String,
        requestID: Int,
        requireMatch: Bool,
        then: (() -> Void)?
    ) {
        guard artwork == nil else { then?(); return }
        var components = URLComponents(string: "https://api-v2.soundcloud.com/search/tracks")
        components?.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components?.url else { then?(); return }

        var request = URLRequest(url: url)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://soundcloud.com", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let collection = json["collection"] as? [[String: Any]]
            else {
                DispatchQueue.main.async { then?() }
                return
            }

            var urls: [String] = []
            for track in collection {
                let title = track["title"] as? String ?? ""
                let user = (track["user"] as? [String: Any])?["username"] as? String ?? ""
                let art = (track["artwork_url"] as? String)
                    ?? ((track["user"] as? [String: Any])?["avatar_url"] as? String)
                    ?? ""
                if !art.isEmpty {
                    urls.append("\(title)\u{1e}\(user)\u{1e}\(art)")
                }
            }

            let picked = Self.pickSoundCloudArtwork(
                records: urls,
                title: self.title,
                artist: self.artist,
                requireMatch: requireMatch
            )
            guard let picked else {
                DispatchQueue.main.async { then?() }
                return
            }
            self.downloadArtwork(from: picked, requestID: requestID, then: then)
        }.resume()
    }

    private static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private static func soundCloudClientID(in text: String) -> String? {
        let patterns = [
            "client_id:\"([A-Za-z0-9]{16,})\"",
            "client_id:'([A-Za-z0-9]{16,})'",
            "client_id=([A-Za-z0-9]{16,})"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let captured = Range(match.range(at: 1), in: text) {
                return String(text[captured])
            }
        }
        return nil
    }

    private static func soundCloudScriptURLs(in html: String) -> [URL] {
        guard let regex = try? NSRegularExpression(pattern: "https://a-v2\\.sndcdn\\.com/assets/[^\"']+\\.js") else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let urls = regex.matches(in: html, range: range).compactMap { match -> URL? in
            guard let captured = Range(match.range, in: html) else { return nil }
            return URL(string: String(html[captured]))
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    private static let messengerVideoMinDuration = 5.0
    private static let musicMinDuration = 10.0

    private static func shouldShowNowPlaying(
        appName: String,
        bundleID: String,
        duration: Double,
        isVideo: Bool
    ) -> Bool {
        if isMessenger(appName: appName, bundleID: bundleID) {
            if isVideo { return duration >= messengerVideoMinDuration }
            return duration >= musicMinDuration
        }
        if duration > 0, duration < musicMinDuration { return false }
        return true
    }

    private static func looksLikeBrowser(_ appName: String) -> Bool {
        let lower = appName.lowercased()
        return ["safari", "chrome", "firefox", "arc", "brave", "edge", "opera", "dia", "orion"]
            .contains { lower.contains($0) }
    }

    private static func isMessenger(appName: String, bundleID: String) -> Bool {
        let blob = "\(appName) \(bundleID)".lowercased()
        guard !blob.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let tokens = [
            "telegram", "keepcoder.telegram", "tdesktop", "telegra",
            "whatsapp",
            "discord",
            "slack", "tinyspeck",
            "viber",
            "signal", "whispersystems",
            "skype",
            "messages", "ichat", "mobilesms",
            "facetime",
            "imessage"
        ]
        return tokens.contains { blob.contains($0) }
    }

    private static func pickSoundCloudArtwork(records: [String], title: String, artist: String, requireMatch: Bool) -> String? {
        let titleFold = title.lowercased()
        let artistFold = artist.lowercased()
        var best: (score: Int, url: String)?
        for record in records {
            let parts = record.split(separator: "\u{1e}", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { continue }
            let name = parts[0].lowercased()
            let user = parts[1].lowercased()
            let url = parts[2]
            var score = 1
            if !titleFold.isEmpty, name.contains(titleFold) || titleFold.contains(name) { score += 3 }
            if !artistFold.isEmpty, name.contains(artistFold) || user.contains(artistFold) { score += 2 }
            if best == nil || score > best!.score {
                best = (score, url)
            }
        }
        guard let best else { return nil }
        if requireMatch, best.score < 3 { return nil }
        return best.url
    }

    private func downloadArtwork(from url: URL, requestID: Int, then: (() -> Void)? = nil) {
        downloadArtwork(from: url.absoluteString, requestID: requestID, then: then)
    }

    private func downloadArtwork(from rawURL: String, requestID: Int, then: (() -> Void)? = nil) {
        let candidates = Self.artworkURLCandidates(rawURL)
        func tryAt(_ index: Int) {
            guard index < candidates.count else {
                DispatchQueue.main.async { then?() }
                return
            }
            var request = URLRequest(url: candidates[index])
            request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://soundcloud.com", forHTTPHeaderField: "Referer")
            request.setValue("https://soundcloud.com", forHTTPHeaderField: "Origin")
            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self else { return }
                if let data, let image = Self.artworkImage(from: data) {
                    DispatchQueue.main.async {
                        guard requestID == self.artworkRequestID else { return }
                        if self.artwork == nil { self.artwork = image }
                        then?()
                    }
                    return
                }
                tryAt(index + 1)
            }.resume()
        }
        tryAt(0)
    }

    private static func isArtworkURL(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("http://")
            || value.hasPrefix("https://")
            || value.hasPrefix("//")
            || value.contains("sndcdn.com")
    }

    private static func artworkURLCandidates(_ raw: String) -> [URL] {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("//") { value = "https:" + value }
        if value.contains("sndcdn.com"), !value.hasPrefix("http") {
            value = "https://" + value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        var seen = Set<String>()
        var urls: [URL] = []
        func add(_ string: String) {
            guard let url = URL(string: string), seen.insert(string).inserted else { return }
            urls.append(url)
        }

        if value.contains("sndcdn.com") {
            let compact = value
                .replacingOccurrences(of: "-original.", with: "-t300x300.")
                .replacingOccurrences(of: "-t500x500.", with: "-t300x300.")
                .replacingOccurrences(of: "-large.", with: "-t300x300.")
                .replacingOccurrences(of: "original.jpg", with: "t300x300.jpg")
                .replacingOccurrences(of: "large.jpg", with: "t300x300.jpg")
                .replacingOccurrences(of: "large.png", with: "t300x300.png")
            add(compact)
        }
        add(value)
        return urls
    }

    private static func mediaRemoteArtworkScript(dumpPath: String) -> String {
        let escaped = dumpPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return """
        function run() {
          try {
            ObjC.import('Foundation');
            const MediaRemote = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
            MediaRemote.load;
            const MRNowPlayingRequest = $.NSClassFromString('MRNowPlayingRequest');
            const item = MRNowPlayingRequest.localNowPlayingItem;
            if (!item) return "";
            const info = item.nowPlayingInfo;

            function asText(value) {
              if (!value) return "";
              if (value.js !== undefined) return String(value.js);
              try { return String(value); } catch (e) { return ""; }
            }

            function asURL(value) {
              let s = asText(value).trim();
              if (!s) return "";
              if (s.indexOf("//") === 0) s = "https:" + s;
              if (s.indexOf("sndcdn.com") !== -1 && s.indexOf("http") !== 0) {
                s = "https://" + s.replace(/^\\/+/, "");
              }
              if (s.indexOf("http://") === 0 || s.indexOf("https://") === 0) return s;
              return "";
            }

            const urlKeys = [
              'kMRMediaRemoteNowPlayingInfoArtworkURL',
              'artworkURL',
              'artworkUrl',
              'artwork_url',
              'kMRMediaRemoteNowPlayingInfoArtworkIdentifier'
            ];
            for (let i = 0; i < urlKeys.length; i++) {
              const found = asURL(info.valueForKey(urlKeys[i]));
              if (found) return found;
            }

            try {
              const all = info.allKeys;
              const n = Number(all.count);
              for (let i = 0; i < n; i++) {
                const found = asURL(info.objectForKey(all.objectAtIndex(i)));
                if (found) return found;
              }
            } catch (e) {}

            const keys = [
              'kMRMediaRemoteNowPlayingInfoArtworkData',
              'artworkData',
              'kMRMediaRemoteNowPlayingInfoArtwork'
            ];
            let data = null;
            for (let i = 0; i < keys.length; i++) {
              const v = info.valueForKey(keys[i]);
              if (v && v.length && Number(v.length) > 16) {
                data = v;
                break;
              }
            }
            if (!data) return "";
            const out = '\(escaped)';
            data.writeToFileAtomically($(out), true);
            return out;
          } catch (e) {
            return "";
          }
        }
        """
    }

    private func fetchCatalogArtwork(requestID: Int) {
        guard artwork == nil else { return }
        let term = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
        guard !term.isEmpty else { return }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let raw = first["artworkUrl100"] as? String
            else { return }

            guard let artURL = URL(string: raw) else { return }

            URLSession.shared.dataTask(with: artURL) { [weak self] data, _, _ in
                guard let self, let data, let image = Self.artworkImage(from: data) else { return }
                DispatchQueue.main.async {
                    guard requestID == self.artworkRequestID, self.artwork == nil else { return }
                    self.artwork = image
                }
            }.resume()
        }.resume()
    }

    private static let artworkMaxPixel = 96

    private static func artworkImage(from data: Data) -> NSImage? {
        thumbnail(CGImageSourceCreateWithData(data as CFData, nil))
    }

    private static func image(fromFile path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        return thumbnail(CGImageSourceCreateWithURL(url as CFURL, nil))
            ?? NSImage(contentsOfFile: path)
    }

    private static func thumbnail(_ source: CGImageSource?) -> NSImage? {
        guard let source else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: artworkMaxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private func fetchSpotifyArtwork(requestID: Int) {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    return artwork url of current track
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        runAppleScript(script) { [weak self] urlString in
            guard let self, requestID == self.artworkRequestID else { return }
            guard !urlString.isEmpty, let url = URL(string: urlString) else {
                self.fetchMediaRemoteArtwork(requestID: requestID)
                return
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                guard let data, let image = Self.artworkImage(from: data) else {
                    DispatchQueue.main.async {
                        guard requestID == self.artworkRequestID else { return }
                        self.fetchMediaRemoteArtwork(requestID: requestID)
                    }
                    return
                }
                DispatchQueue.main.async {
                    guard requestID == self.artworkRequestID else { return }
                    self.artwork = image
                }
            }.resume()
        }
    }

    enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    func pausePlayback() {
        let current = elapsed(at: Date())
        displayedElapsed = current
        elapsedAtLastFetch = current
        fetchedAt = Date()
        _ = sendCommandFn?(Command.pause.rawValue, nil)
        isPlaying = false
        pausedPolls = 2
    }

    func resumePlayback() {
        elapsedAtLastFetch = displayedElapsed
        fetchedAt = Date()
        _ = sendCommandFn?(Command.play.rawValue, nil)
        isPlaying = true
        pausedPolls = 0
    }

    func openPlayer() {
        let lower = appName.lowercased()
        let ids: [String]
        if lower.contains("spotify") {
            ids = ["com.spotify.client"]
        } else if lower.contains("soundcloud") {
            ids = ["com.soundcloud.desktop", "com.soundcloud.mac", "com.soundcloud.SoundCloud"]
        } else {
            ids = ["com.apple.Music"]
        }
        for id in ids {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    func send(_ command: Command) {
        if command == .nextTrack || command == .previousTrack {
            sendSkip(forward: command == .nextTrack)
        } else {
        _ = sendCommandFn?(command.rawValue, nil)
        }
        if command == .togglePlayPause {
            if isPlaying {
                freezeClock()
                isPlaying = false
                pausedPolls = 2
                holdElapsedUntil = Date().addingTimeInterval(2)
            } else {
                elapsedAtLastFetch = displayedElapsed
                fetchedAt = Date()
                isPlaying = true
                pausedPolls = 0
            }
        }
        if useFallbackPolling {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refreshOneShot()
            }
        }
    }

    private func sendSkip(forward: Bool) {
        let verb = forward ? "next track" : "previous track"
        let lower = appName.lowercased()
        if lower.contains("spotify") {
            runAppleScript("if application \"Spotify\" is running then tell application \"Spotify\" to \(verb)") { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.lastTrackKey = nil
                    self?.refresh()
                }
            }
            return
        }
        if musicIsSource || lower.contains("music") || lower.contains("музык") || lower.contains("itunes") {
            runAppleScript("if application \"Music\" is running then tell application \"Music\" to \(verb)") { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.lastTrackKey = nil
                    self?.pollMusicApp()
                }
            }
            return
        }
        _ = sendCommandFn?(forward ? Command.nextTrack.rawValue : Command.previousTrack.rawValue, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.lastTrackKey = nil
            self?.refresh()
        }
    }

    func seek(to seconds: Double) {
        let target = clamped(seconds)
        let wasPlaying = isPlaying
        isScrubbing = false
        holdElapsedUntil = Date().addingTimeInterval(2)
        setElapsedTimeFn?(target)
        elapsedAtLastFetch = target
        fetchedAt = Date()
        displayedElapsed = target
        if wasPlaying {
            _ = sendCommandFn?(Command.play.rawValue, nil)
            isPlaying = true
        }
    }

    private func applyPlaybackState(_ playing: Bool) {
        if playing {
            pausedPolls = 0
            if !isPlaying { isPlaying = true }
            return
        }
        pausedPolls += 1
        if pausedPolls >= 2, isPlaying {
            freezeClock()
            isPlaying = false
        }
    }

    private func applyElapsed(_ elapsed: Double, playing: Bool, trackChanged: Bool) {
        if isScrubbing { return }

        if trackChanged {
            holdElapsedUntil = nil
            pausedPolls = 0
            if elapsed >= 1 || !playing {
                setAnchor(elapsed)
            } else {
                elapsedAtLastFetch = 0
                fetchedAt = Date()
                displayedElapsed = 0
            }
            return
        }

        let projected = elapsedAtLastFetch + (isPlaying ? Date().timeIntervalSince(fetchedAt) : 0)

        if let hold = holdElapsedUntil {
            if Date() < hold {
                if elapsed + 0.4 >= elapsedAtLastFetch, abs(elapsed - elapsedAtLastFetch) < 2 {
                    setAnchor(elapsed)
                    holdElapsedUntil = nil
                }
                return
            }
            holdElapsedUntil = nil
        }

        if playing || isPlaying {
            if elapsed + 0.75 < projected {
                return
            }
            if elapsed > projected + 1.8 {
                setAnchor(elapsed)
            }
            return
        }

        if pausedPolls >= 2, elapsed + 0.4 >= elapsedAtLastFetch {
            setAnchor(elapsed)
        }
    }

    private func freezeClock() {
        let current = elapsed(at: Date())
        elapsedAtLastFetch = current
        fetchedAt = Date()
        displayedElapsed = current
    }

    private func setAnchor(_ seconds: Double) {
        let value = clamped(seconds)
        elapsedAtLastFetch = value
        fetchedAt = Date()
        displayedElapsed = value
    }

    private func clamped(_ seconds: Double) -> Double {
        let value = max(0, seconds)
        return duration > 1 ? min(value, duration) : value
    }

    private func runAppleScript(_ script: String, completion: @escaping (String) -> Void) {
        runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script], completion: completion)
    }

    private func runProcess(executable: String, arguments: [String], completion: @escaping (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        DispatchQueue.global(qos: .utility).async {
            do {
                try process.run()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
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
