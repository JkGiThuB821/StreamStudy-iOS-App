//
//  APIKeys.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

enum APIKeys {
    
    static var youTubeDataAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !key.isEmpty,
              key != "YOUR_YOUTUBE_API_KEY_HERE"
        else {
            return nil
        }
        return key
    }
    
    static var geminiAPIKey: String? {
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
