//
//  APIKeys.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

enum APIKeys {
    static var youTubeKeyOverride: String?
    static var geminiKeyOverride: String?

    static var youTubeDataAPIKey: String? {
        if let override = youTubeKeyOverride { return override.isEmpty ? nil : override }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !key.isEmpty,
              key != "YOUR_YOUTUBE_API_KEY_HERE"
        else {
            return nil
        }
        return key
    }

    static var geminiAPIKey: String? {
        if let override = geminiKeyOverride { return override.isEmpty ? nil : override }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
              !key.isEmpty,
              !key.hasPrefix("$("),
              key != "YOUR_GEMINI_API_KEY_HERE"
        else {
            return nil
        }
        return key
    }
}
