//
//  NotificationService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 5/10/2026.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission failed: \(error.localizedDescription)")
        }
    }

    func scheduleNotifications(for deadlines: [Deadline]) async {
        center.removeAllPendingNotificationRequests()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        for deadline in deadlines where deadline.dueDate > .now {
            let content = UNMutableNotificationContent()
            content.title = "\(deadline.title) is coming up"
            content.body = body(for: deadline)
            content.sound = .default
            content.userInfo = [
                "deepLink": deepLink(for: deadline)
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate(for: deadline)
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
    }

    private func reminderDate(for deadline: Deadline) -> Date {
        let oneDayBefore = deadline.dueDate.addingTimeInterval(-24 * 60 * 60)
        return max(oneDayBefore, Date.now.addingTimeInterval(60))
    }

    private func body(for deadline: Deadline) -> String {
        switch deadline.daysRemaining {
        case 0:
            return "Your deadline is today. Open StreamStudy to continue learning."
        case 1:
            return "Your deadline is tomorrow. Open StreamStudy to see what to study next."
        default:
            return "You have \(deadline.daysRemaining) days left. Open StreamStudy to keep making progress."
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
