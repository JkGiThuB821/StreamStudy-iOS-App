//
//  NotificationService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 5/10/2026.
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    // UserDefaults keys shared with @AppStorage in AccountView / MainTabView.
    static let remindersEnabledKey = "deadlineRemindersEnabled"
    static let reminderLeadDaysKey = "deadlineReminderLeadDays"
    static let weeklyDigestEnabledKey = "weeklyDigestEnabled"
    static let weeklyDigestIdentifier = "weekly-digest"

    struct PendingReminder: Identifiable {
        let id: String
        let title: String
        let body: String
        let fireDate: Date?
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingReminders: [PendingReminder] = []

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private init() {}

    private var remindersEnabled: Bool {
        defaults.object(forKey: Self.remindersEnabledKey) as? Bool ?? true
    }

    private var leadDays: Int {
        let stored = defaults.integer(forKey: Self.reminderLeadDaysKey)
        return stored > 0 ? stored : 1
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission failed: \(error.localizedDescription)")
        }
        await refreshStatus()
    }

    func refreshStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
        await refreshPendingReminders()
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Deadline reminders

    func scheduleNotifications(for deadlines: [Deadline]) async {
        // Only replace deadline reminders, so the weekly digest notification survives.
        let deadlineIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("deadline-") }
        center.removePendingNotificationRequests(withIdentifiers: deadlineIDs)
        authorizationStatus = await center.notificationSettings().authorizationStatus

        guard isAuthorized, remindersEnabled else {
            await refreshPendingReminders()
            return
        }

        for deadline in deadlines where deadline.dueDate > .now {
            let fireDate = reminderDate(for: deadline)

            let content = UNMutableNotificationContent()
            content.title = "\(deadline.title) is coming up"
            content.body = body(for: deadline, firingAt: fireDate)
            content.sound = .default
            content.userInfo = [
                "deepLink": deepLink(for: deadline)
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "deadline-\(deadline.id.uuidString)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("Could not schedule \(deadline.title): \(error.localizedDescription)")
            }
        }

        await refreshPendingReminders()
    }

    // MARK: - Weekly digest (Season Pass)

    // A repeating Monday 9am "episode drop" notification that opens the digest.
    func scheduleWeeklyDigest() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyDigestIdentifier])
        authorizationStatus = await center.notificationSettings().authorizationStatus

        let enabled = defaults.object(forKey: Self.weeklyDigestEnabledKey) as? Bool ?? true
        guard isAuthorized, enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "This week's episodes have dropped"
        content.body = "Your study picks for the week are ready. Swipe to rate what you've learned."
        content.sound = .default
        content.userInfo = ["deepLink": "streamstudy://digest"]

        var monday9am = DateComponents()
        monday9am.weekday = 2
        monday9am.hour = 9
        monday9am.minute = 0

        let request = UNNotificationRequest(
            identifier: Self.weeklyDigestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: monday9am, repeats: true)
        )

        do {
            try await center.add(request)
        } catch {
            print("Could not schedule weekly digest: \(error.localizedDescription)")
        }
    }

    // Fires in 5 seconds so notifications and deep linking can be tested without waiting.
    func sendTestNotification(opensDigest: Bool = false) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = opensDigest ? "This week's episodes have dropped" : "StreamStudy test reminder"
        content.body = opensDigest ? "Tap to open your weekly digest." : "Tap to open your Calendar."
        content.sound = .default
        content.userInfo = ["deepLink": opensDigest ? "streamstudy://digest" : "streamstudy://calendar"]

        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            print("Could not schedule test notification: \(error.localizedDescription)")
        }
    }

    private func refreshPendingReminders() async {
        let requests = await center.pendingNotificationRequests()

        pendingReminders = requests
            .filter { $0.identifier.hasPrefix("deadline-") }
            .map { request in
                PendingReminder(
                    id: request.identifier,
                    title: request.content.title,
                    body: request.content.body,
                    fireDate: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                )
            }
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }

    // MARK: - Helpers

    private func reminderDate(for deadline: Deadline) -> Date {
        // Remind `leadDays` before, but never schedule a notification in the past.
        let leadTime = TimeInterval(leadDays * 24 * 60 * 60)
        return max(deadline.dueDate.addingTimeInterval(-leadTime), Date.now.addingTimeInterval(60))
    }

    private func body(for deadline: Deadline, firingAt fireDate: Date) -> String {
        let calendar = Calendar.current
        let daysLeft = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: fireDate),
            to: calendar.startOfDay(for: deadline.dueDate)
        ).day ?? 0

        switch daysLeft {
        case ...0:
            return "Your deadline is today. Open StreamStudy to continue learning."
        case 1:
            return "Your deadline is tomorrow. Open StreamStudy to see what to study next."
        default:
            return "You have \(daysLeft) days left. Open StreamStudy to keep making progress."
        }
    }

    private func deepLink(for deadline: Deadline) -> String {
        if let topic = deadline.subject?.topics
            .filter({ !$0.isCompleted })
            .sorted(by: { $0.progress < $1.progress })
            .first {
            return "streamstudy://topic/\(topic.id.uuidString)"
        }

        return "streamstudy://calendar/\(deadline.id.uuidString)"
    }
}
