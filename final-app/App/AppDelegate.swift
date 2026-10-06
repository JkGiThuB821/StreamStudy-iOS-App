//
//  AppDelegate.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import UIKit
import UserNotifications
import FirebaseCore

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // Owned here so notification taps (which arrive in the delegate) can reach the router.
    let deepLinkRouter = DeepLinkRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show the banner even when the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // Tapping a notification opens the deep link stored in its userInfo.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo["deepLink"] as? String

        Task { @MainActor in
            if let link, let url = URL(string: link) {
                self.deepLinkRouter.handle(url: url)
            }
            completionHandler()
        }
    }
}
