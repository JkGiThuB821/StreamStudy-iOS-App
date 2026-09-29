//
//  APIKeys.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

enum APIKeys {
    static let youTubeDataAPIKey =
    Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_DATA_API_KEY") as? String ?? ""
}
