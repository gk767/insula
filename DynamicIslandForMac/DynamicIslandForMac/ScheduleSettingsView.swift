import SwiftUI

struct ScheduleSettingsView: View {
    @ObservedObject var schedule: ScheduleManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Что показывать на Insula")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            if !schedule.isAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Нужен доступ к Календарю и Напоминаниям macOS.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Button("Разрешить") {
                        schedule.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        calendarSection(
                            title: "Календари",
                            empty: "Нет календарей",
                            items: schedule.availableCalendars
                        ) { id, enabled in
                            schedule.setCalendarEnabled(id, enabled: enabled)
                        }

                        calendarSection(
                            title: "Списки напоминаний",
                            empty: "Нет списков",
                            items: schedule.availableReminderLists
                        ) { id, enabled in
                            schedule.setReminderListEnabled(id, enabled: enabled)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Рабочие часы", isOn: $schedule.workHoursEnabled)
                            if schedule.workHoursEnabled {
                                HStack(spacing: 16) {
                                    Stepper(value: $schedule.workStartHour, in: 0...23) {
                                        Text("С \(schedule.workStartHour):00")
                                            .monospacedDigit()
                                    }
                                    Stepper(value: $schedule.workEndHour, in: 0...23) {
                                        Text("До \(schedule.workEndHour):00")
                                            .monospacedDigit()
                                    }
                                }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Готово") {
                    schedule.isSettingsOpen = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 340, height: 420)
    }

    @ViewBuilder
    private func calendarSection(
        title: String,
        empty: String,
        items: [ScheduleCalendarInfo],
        onToggle: @escaping (String, Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            if items.isEmpty {
                Text(empty)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    Toggle(isOn: Binding(
                        get: { item.isEnabled },
                        set: { onToggle(item.id, $0) }
                    )) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.title)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}
