import AppKit
import ApplicationServices
import Combine
import UserNotifications

final class PermissionGate: ObservableObject {

    enum Status {
        case unknown
        case allowed
        case denied
        case missing
    }

    @Published var notifications: Status = .unknown
    @Published var music: Status = .unknown
    @Published var spotify: Status = .unknown

    private nonisolated static let musicID = "com.apple.Music"
    private nonisolated static let spotifyID = "com.spotify.client"
    private static let didExplainKey = "permission.didExplain"

    nonisolated var spotifyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.spotifyID) != nil
    }

    var needsAttention: Bool {
        notifications == .denied || music == .denied || spotify == .denied
    }

    func requestEverything() {
        let explain = !UserDefaults.standard.bool(forKey: Self.didExplainKey)
        if explain {
            showExplanation()
            UserDefaults.standard.set(true, forKey: Self.didExplainKey)
        }

        requestNotifications { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let self else { return }
                let musicStatus = self.probeAutomation(bundleID: Self.musicID, prompt: true)
                let spotifyStatus: Status
                if self.spotifyInstalled {
                    spotifyStatus = self.probeAutomation(bundleID: Self.spotifyID, prompt: true)
                } else {
                    spotifyStatus = .missing
                }
                DispatchQueue.main.async {
                    self.music = musicStatus
                    self.spotify = spotifyStatus
                    self.refreshNotificationStatus()
                }
            }
        }
    }

    func requestAutomation(prompt: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let musicStatus = self.probeAutomation(bundleID: Self.musicID, prompt: prompt)
            let spotifyStatus = self.spotifyInstalled
                ? self.probeAutomation(bundleID: Self.spotifyID, prompt: prompt)
                : .missing
            DispatchQueue.main.async {
                self.music = musicStatus
                self.spotify = spotifyStatus
            }
        }
    }

    func refreshQuietly() {
        refreshNotificationStatus()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let musicStatus = self.probeAutomation(bundleID: Self.musicID, prompt: false)
            let spotifyStatus = self.spotifyInstalled
                ? self.probeAutomation(bundleID: Self.spotifyID, prompt: false)
                : .missing
            DispatchQueue.main.async {
                self.music = musicStatus
                self.spotify = spotifyStatus
            }
        }
    }

    func openAutomationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.settings.Notifications"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    private func showExplanation() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Нужны доступы для острова"
        alert.informativeText = """
        Чтобы показывать трек, обложки и уведомление таймера, macOS спросит несколько разрешений:

        • Уведомления — когда таймер закончится
        • Музыка — название, прогресс и обложка текущего трека
        • Spotify — обложка, если слушаете там

        В каждом окне нажмите «OK». Иначе Apple Music может не появиться в острове.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Продолжить")
        alert.runModal()
    }

    private func requestNotifications(then: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshNotificationStatus()
                then()
            }
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self?.notifications = .allowed
                case .denied:
                    self?.notifications = .denied
                default:
                    self?.notifications = .unknown
                }
            }
        }
    }

    nonisolated private func probeAutomation(bundleID: String, prompt: Bool) -> Status {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let aeDesc = target.aeDesc else { return .unknown }

        let status = AEDeterminePermissionToAutomateTarget(
            UnsafeMutablePointer(mutating: aeDesc),
            typeWildCard,
            typeWildCard,
            prompt
        )

        switch status {
        case noErr:
            return .allowed
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .unknown
        case OSStatus(procNotFound):
            return .missing
        default:
            return prompt ? .denied : .unknown
        }
    }
}

extension PermissionGate.Status {
    var menuLabel: String {
        switch self {
        case .allowed: return "есть"
        case .denied: return "нет"
        case .missing: return "не установлен"
        case .unknown: return "…"
        }
    }
}
