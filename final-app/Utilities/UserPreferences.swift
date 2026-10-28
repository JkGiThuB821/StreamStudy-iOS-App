//
//  UserPreferences.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 14/10/2026.
//

import Foundation

// UserDefaults keys shared by onboarding, Home and Account.
// (The theme uses AppAppearance.storageKey in Theme.swift.)
enum UserPreferences {
    // Comma-separated Firebase user IDs that have finished onboarding on this device.
    static let onboardedUserIDsKey = "onboardedUserIDs"

    // Set by Account → "Show Onboarding Again" to replay it on purpose.
    static let replayOnboardingKey = "replayOnboarding"

    // Display name saved on the device, so it works offline.
    static func displayNameKey(for uid: String) -> String {
        "displayName.\(uid)"
    }

    static func hasOnboarded(_ uid: String, in list: String) -> Bool {
        list.split(separator: ",").contains { $0 == uid }
    }

    static func adding(_ uid: String, to list: String) -> String {
        hasOnboarded(uid, in: list) ? list : (list.isEmpty ? uid : "\(list),\(uid)")
    }

    static func removing(_ uid: String, from list: String) -> String {
        list.split(separator: ",").filter { $0 != uid }.joined(separator: ",")
    }
}
