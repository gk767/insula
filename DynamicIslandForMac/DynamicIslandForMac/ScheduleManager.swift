import AppKit
import EventKit
import SwiftUI
import Combine

struct ScheduleItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case event
        case reminder
    }

    let id: String
    let title: String
    let date: Date
    let kind: Kind
    let isAllDay: Bool
    let calendarColor: Color?
    let isOverdue: Bool

    var minutesUntil: Int? {
        guard !isAllDay else { return nil }
        return Int(ceil(date.timeIntervalSinceNow / 60))
    }

    var isUrgent: Bool {
        guard let minutes = minutesUntil else { return false }
        return minutes <= 5 && minutes >= 0
    }

    var isSoon: Bool {
        guard let minutes = minutesUntil else { return false }
        return minutes <= 60 && minutes >= 0
    }
}

struct ScheduleCalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let color: Color
    var isEnabled: Bool
}

final class ScheduleManager: ObservableObject {
    @Published private(set) var eventsAccess: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var remindersAccess: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @Published private(set) var nextItem: ScheduleItem?
    @Published private(set) var todayEvents: [ScheduleItem] = []
    @Published private(set) var todayReminders: [ScheduleItem] = []
    @Published private(set) var availableCalendars: [ScheduleCalendarInfo] = []
    @Published private(set) var availableReminderLists: [ScheduleCalendarInfo] = []
    @Published var isSettingsOpen = false
    @Published var workHoursEnabled: Bool
    @Published var workStartHour: Int
    @Published var workEndHour: Int

    var onNudge: ((String, String) -> Void)?

    var isAuthorized: Bool {
        hasEventsAccess && hasRemindersAccess
    }

    var hasEventsAccess: Bool {
        Self.isGranted(eventsAccess)
    }

    var hasRemindersAccess: Bool {
        Self.isGranted(remindersAccess)
    }

    var todayEventCount: Int { todayEvents.count }
    var todayReminderCount: Int { todayReminders.count }

    var collapsedAccentColor: Color? {
        guard let nextItem, nextItem.isUrgent else { return nil }
        return nextItem.calendarColor
    }

    private let store = EKEventStore()
    private var refreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var enabledCalendarIDs: Set<String>
    private var enabledReminderListIDs: Set<String>
    private var nudgedKeys: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        workHoursEnabled = UserDefaults.standard.object(forKey: Self.workHoursEnabledKey) as? Bool ?? false
        workStartHour = UserDefaults.standard.object(forKey: Self.workStartHourKey) as? Int ?? 10
        workEndHour = UserDefaults.standard.object(forKey: Self.workEndHourKey) as? Int ?? 19
        if let saved = UserDefaults.standard.array(forKey: Self.enabledCalendarsKey) as? [String] {
            enabledCalendarIDs = Set(saved)
        } else {
            enabledCalendarIDs = []
        }
        if let saved = UserDefaults.standard.array(forKey: Self.enabledReminderListsKey) as? [String] {
            enabledReminderListIDs = Set(saved)
        } else {
            enabledReminderListIDs = []
        }

        $workHoursEnabled.dropFirst().sink { [weak self] value in
            UserDefaults.standard.set(value, forKey: Self.workHoursEnabledKey)
            self?.refresh()
        }.store(in: &cancellables)

        $workStartHour.dropFirst().sink { [weak self] value in
            UserDefaults.standard.set(value, forKey: Self.workStartHourKey)
            self?.refresh()
        }.store(in: &cancellables)

        $workEndHour.dropFirst().sink { [weak self] value in
            UserDefaults.standard.set(value, forKey: Self.workEndHourKey)
            self?.refresh()
        }.store(in: &cancellables)

        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.eventsAccess = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.refresh() }
                }
            }
            store.requestFullAccessToReminders { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.remindersAccess = EKEventStore.authorizationStatus(for: .reminder)
                    if granted { self?.refresh() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.eventsAccess = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.refresh() }
                }
            }
            store.requestAccess(to: .reminder) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.remindersAccess = EKEventStore.authorizationStatus(for: .reminder)
                    if granted { self?.refresh() }
                }
            }
        }
    }

    func refreshAuthorizationStatus() {
        eventsAccess = EKEventStore.authorizationStatus(for: .event)
        remindersAccess = EKEventStore.authorizationStatus(for: .reminder)
    }

    func refresh() {
        refreshAuthorizationStatus()
        guard isAuthorized else {
            nextItem = nil
            todayEvents = []
            todayReminders = []
            availableCalendars = []
            return
        }

        loadCalendars()
        let events = fetchTodayEvents()
        todayEvents = events
        fetchTodayReminders { [weak self] reminders in
            guard let self else { return }
            self.todayReminders = reminders
            self.nextItem = self.pickNextItem(events: events, reminders: reminders)
            self.checkNudges(events: events, reminders: reminders)
        }
    }

    func isCalendarEnabled(_ id: String) -> Bool {
        enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(id)
    }

    func setCalendarEnabled(_ id: String, enabled: Bool) {
        setListEnabled(id: id, enabled: enabled, all: availableCalendars.map(\.id), storage: &enabledCalendarIDs, key: Self.enabledCalendarsKey)
        syncCalendarList()
        refresh()
    }

    func isReminderListEnabled(_ id: String) -> Bool {
        enabledReminderListIDs.isEmpty || enabledReminderListIDs.contains(id)
    }

    func setReminderListEnabled(_ id: String, enabled: Bool) {
        setListEnabled(
            id: id,
            enabled: enabled,
            all: availableReminderLists.map(\.id),
            storage: &enabledReminderListIDs,
            key: Self.enabledReminderListsKey
        )
        syncReminderList()
        refresh()
    }

    func toggleSettings() {
        isSettingsOpen.toggle()
        if isSettingsOpen {
            refreshAuthorizationStatus()
            refresh()
        }
    }

    private func setListEnabled(
        id: String,
        enabled: Bool,
        all: [String],
        storage: inout Set<String>,
        key: String
    ) {
        var ids = storage
        if ids.isEmpty {
            ids = Set(all)
        }
        if enabled {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        if ids.count == all.count {
            storage = []
        } else {
            storage = ids
        }
        UserDefaults.standard.set(Array(storage), forKey: key)
    }

    func openNextItemApp() {
        guard let nextItem else { return }
        openApp(for: nextItem.kind)
    }

    func openApp(for kind: ScheduleItem.Kind) {
        let bundleID = kind == .event ? "com.apple.iCal" : "com.apple.reminders"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }

    func collapsedText(now: Date = Date()) -> String? {
        collapsedShortText(now: now)
    }

    func collapsedShortText(now: Date = Date()) -> String? {
        guard let nextItem else { return nil }
        if nextItem.isAllDay { return "день" }
        let minutes = nextItem.minutesUntil ?? Int(ceil(nextItem.date.timeIntervalSince(now) / 60))
        if minutes >= 0, minutes <= 60 {
            return "\(minutes)м"
        }
        return timeString(nextItem.date)
    }

    func countdownProgress(for item: ScheduleItem?) -> Double {
        guard let item, !item.isAllDay, let minutes = item.minutesUntil, minutes >= 0 else { return 0 }
        if minutes > 60 { return 0.08 }
        return 1 - min(1, Double(minutes) / 60)
    }

    var timelineItems: [ScheduleItem] {
        var seen = Set<String>()
        return (todayEvents + todayReminders)
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue && !rhs.isOverdue }
                return lhs.date < rhs.date
            }
            .filter { seen.insert($0.id).inserted }
            .prefix(4)
            .map { $0 }
    }

    func collapsedBadgeText() -> String? {
        guard todayEventCount > 0 || todayReminderCount > 0 else { return nil }
        if todayEventCount > 0, todayReminderCount > 0 {
            return "\(todayEventCount)+\(todayReminderCount)"
        }
        if todayEventCount > 0 {
            return "\(todayEventCount)"
        }
        return "\(todayReminderCount)"
    }

    func notificationItems() -> [ScheduleNotificationRequest] {
        guard isAuthorized else { return [] }
        var items: [ScheduleNotificationRequest] = []
        let now = Date()

        for event in todayEvents where !event.isAllDay {
            let offsets = [15, 5]
            for offset in offsets {
                let fireDate = event.date.addingTimeInterval(TimeInterval(-offset * 60))
                guard fireDate > now else { continue }
                items.append(
                    ScheduleNotificationRequest(
                        id: "event-\(event.id)-\(offset)",
                        title: offset == 5 ? "Скоро: \(event.title)" : event.title,
                        body: "Через \(offset) мин",
                        fireDate: fireDate
                    )
                )
            }
        }

        for reminder in todayReminders where !reminder.isAllDay {
            let offsets: [Int]
            if reminder.isOverdue {
                offsets = []
            } else if let minutes = reminder.minutesUntil, minutes >= 15 {
                offsets = [15, 0]
            } else {
                offsets = [0]
            }
            for offset in offsets {
                let fireDate = reminder.date.addingTimeInterval(TimeInterval(-offset * 60))
                guard fireDate > now else { continue }
                items.append(
                    ScheduleNotificationRequest(
                        id: "reminder-\(reminder.id)-\(offset)",
                        title: reminder.title,
                        body: offset == 0 ? "Пора" : "Через \(offset) мин",
                        fireDate: fireDate
                    )
                )
            }
        }

        return items
    }

    private func loadCalendars() {
        let eventCalendars = store.calendars(for: .event).map {
            ScheduleCalendarInfo(
                id: $0.calendarIdentifier,
                title: $0.title,
                color: Color(cgColor: $0.cgColor),
                isEnabled: isCalendarEnabled($0.calendarIdentifier)
            )
        }
        availableCalendars = eventCalendars.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let reminderLists = store.calendars(for: .reminder).map {
            ScheduleCalendarInfo(
                id: $0.calendarIdentifier,
                title: $0.title,
                color: Color(cgColor: $0.cgColor),
                isEnabled: isReminderListEnabled($0.calendarIdentifier)
            )
        }
        availableReminderLists = reminderLists.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func syncReminderList() {
        availableReminderLists = availableReminderLists.map { info in
            var copy = info
            copy.isEnabled = isReminderListEnabled(info.id)
            return copy
        }
    }

    private func selectedReminderCalendars() -> [EKCalendar] {
        let all = store.calendars(for: .reminder)
        guard !enabledReminderListIDs.isEmpty else { return all }
        return all.filter { enabledReminderListIDs.contains($0.calendarIdentifier) }
    }

    private func syncCalendarList() {
        availableCalendars = availableCalendars.map { info in
            var copy = info
            copy.isEnabled = isCalendarEnabled(info.id)
            return copy
        }
    }

    private func selectedEventCalendars() -> [EKCalendar] {
        let all = store.calendars(for: .event)
        guard !enabledCalendarIDs.isEmpty else { return all }
        return all.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
    }

    private func fetchTodayEvents() -> [ScheduleItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selectedEventCalendars())
        let events = store.events(matching: predicate)
        return events
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                guard passesWorkHoursFilter(date: event.startDate, isAllDay: event.isAllDay) else { return nil }
                return ScheduleItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Без названия",
                    date: event.startDate,
                    kind: .event,
                    isAllDay: event.isAllDay,
                    calendarColor: Color(cgColor: event.calendar.cgColor),
                    isOverdue: false
                )
            }
    }

    private func fetchTodayReminders(completion: @escaping ([ScheduleItem]) -> Void) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            completion([])
            return
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: end,
            calendars: selectedReminderCalendars()
        )

        store.fetchReminders(matching: predicate) { [weak self] reminders in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let result = (reminders ?? []).compactMap { reminder -> ScheduleItem? in
                guard let components = reminder.dueDateComponents,
                      let dueDate = calendar.date(from: components) else { return nil }
                let isToday = dueDate >= start && dueDate < end
                let isOverdue = dueDate < start
                guard isToday || isOverdue else { return nil }
                let hasTime = components.hour != nil
                let itemDate = hasTime ? dueDate : end.addingTimeInterval(-60)
                guard self.passesWorkHoursFilter(date: itemDate, isAllDay: !hasTime) else { return nil }
                return ScheduleItem(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title ?? "Без названия",
                    date: itemDate,
                    kind: .reminder,
                    isAllDay: !hasTime,
                    calendarColor: Color(cgColor: reminder.calendar.cgColor),
                    isOverdue: isOverdue
                )
            }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue && !rhs.isOverdue }
                return lhs.date < rhs.date
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func pickNextItem(events: [ScheduleItem], reminders: [ScheduleItem]) -> ScheduleItem? {
        let now = Date()
        if let upcomingEvent = events.first(where: { !$0.isAllDay && $0.date > now }) {
            return upcomingEvent
        }
        if let allDayEvent = events.first(where: { $0.isAllDay }) {
            return allDayEvent
        }
        if let upcomingReminder = reminders.first(where: { !$0.isAllDay && ($0.date > now || $0.isOverdue) }) {
            return upcomingReminder
        }
        return reminders.first
    }

    private func passesWorkHoursFilter(date: Date, isAllDay: Bool) -> Bool {
        guard workHoursEnabled, !isAllDay else { return true }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let nowHour = calendar.component(.hour, from: Date())
        let inWorkHours = (workStartHour...workEndHour).contains(hour)
        if inWorkHours { return true }
        let minutesUntil = date.timeIntervalSinceNow / 60
        if minutesUntil >= 0, minutesUntil <= 120 { return true }
        if (workStartHour...workEndHour).contains(nowHour) { return false }
        return false
    }

    private func checkNudges(events: [ScheduleItem], reminders: [ScheduleItem]) {
        let candidates = (events + reminders).filter { !$0.isAllDay && !$0.isOverdue }
        let thresholds = [15, 5]
        let now = Date()

        for item in candidates {
            let minutes = Int(ceil(item.date.timeIntervalSince(now) / 60))
            for threshold in thresholds where minutes == threshold {
                let key = "\(item.id)|\(threshold)"
                guard !nudgedKeys.contains(key) else { continue }
                nudgedKeys.insert(key)
                let title = threshold == 5 ? "Скоро: \(item.title)" : item.title
                onNudge?(title, "Через \(threshold) мин")
            }
        }

        let activeIDs = Set(candidates.map(\.id))
        nudgedKeys = nudgedKeys.filter { key in
            guard let separator = key.lastIndex(of: "|") else { return false }
            let id = String(key[..<separator])
            return activeIDs.contains(id)
        }
    }

    private func truncatedTitle(_ title: String, max: Int) -> String {
        guard title.count > max else { return title }
        return String(title.prefix(max - 1)) + "…"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func isGranted(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .authorized
        }
        return status == .authorized
    }

    private static let workHoursEnabledKey = "schedule.workHours.enabled"
    private static let workStartHourKey = "schedule.workHours.start"
    private static let workEndHourKey = "schedule.workHours.end"
    private static let enabledCalendarsKey = "schedule.calendars.enabled"
    private static let enabledReminderListsKey = "schedule.reminders.enabled"
}

struct ScheduleNotificationRequest: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}
