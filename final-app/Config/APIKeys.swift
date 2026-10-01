//
//  APIKeys.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

enum APIKeys {
    /// nil if Secrets.xcconfig isn't wired up yet, or the key is still the
    /// placeholder value — callers (YouTubeService) treat both as "no key".
    static var youTubeDataAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !key.isEmpty,
              key != "YOUR_YOUTUBE_API_KEY_HERE"
        else {
            return nil
        }
        return key
    }
}
