import AppKit
import UserNotifications

final class TimerFinishNotifier: NSObject, UNUserNotificationCenterDelegate {

    private var alarmSound: NSSound?
    private var alarmWork: DispatchWorkItem?

    func attachAsDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func announceFinish(then: (() -> Void)? = nil) {
        playAlarm(seconds: 2.8, then: then)
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self?.postNotification()
                }
            }
        }
    }

    func stopAlarm() {
        alarmWork?.cancel()
        alarmWork = nil
        alarmSound?.stop()
        alarmSound = nil
    }

    private func playAlarm(seconds: TimeInterval, then: (() -> Void)?) {
        stopAlarm()

        let names = ["Glass", "Ping", "Submarine", "Hero", "Tink"]
        var sound: NSSound?
        for name in names {
            if let found = NSSound(named: NSSound.Name(name)) {
                sound = found
                break
            }
        }

        if let sound {
            sound.loops = true
            sound.volume = 0.9
            sound.play()
            alarmSound = sound
        } else {
            NSSound.beep()
        }

        let work = DispatchWorkItem { [weak self] in
            self?.stopAlarm()
            then?()
        }
        alarmWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Таймер"
        content.body = "Время вышло"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "island.timer.finished",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
