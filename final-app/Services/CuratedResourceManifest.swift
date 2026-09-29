//
//  CuratedResourceManifest.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 29/9/2026.
//

import Foundation

struct CuratedLink: Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let sourceName: String
    let estimatedMinutes: Int
}

enum CuratedResourceManifest {

    private static let manifest: [String: [CuratedLink]] = [
        "swift": [
            CuratedLink(title: "The Swift Programming Language", url: "https://docs.swift.org/swift-book/", sourceName: "Swift.org", estimatedMinutes: 20),
            CuratedLink(title: "Swift by Sundell", url: "https://www.swiftbysundell.com/", sourceName: "Swift by Sundell", estimatedMinutes: 15),
        ],
        "swiftui": [
            CuratedLink(title: "Introducing SwiftUI", url: "https://developer.apple.com/tutorials/swiftui", sourceName: "Apple Developer", estimatedMinutes: 25),
            CuratedLink(title: "100 Days of SwiftUI", url: "https://www.hackingwithswift.com/100/swiftui", sourceName: "Hacking with Swift", estimatedMinutes: 20),
        ],
        "swiftdata": [
            CuratedLink(title: "SwiftData documentation", url: "https://developer.apple.com/documentation/swiftdata", sourceName: "Apple Developer", estimatedMinutes: 20),
            CuratedLink(title: "SwiftData by Example", url: "https://www.hackingwithswift.com/quick-start/swiftdata", sourceName: "Hacking with Swift", estimatedMinutes: 15),
        ],
        "ios": [
            CuratedLink(title: "iOS App Dev Tutorials", url: "https://developer.apple.com/tutorials/app-dev-training", sourceName: "Apple Developer", estimatedMinutes: 30),
            CuratedLink(title: "NSHipster", url: "https://nshipster.com/", sourceName: "NSHipster", estimatedMinutes: 15),
        ],
        "algorithms": [
            CuratedLink(title: "Big O Notation Explained", url: "https://www.freecodecamp.org/news/big-o-notation-why-it-matters-and-why-it-doesnt-1674cfa8a23c/", sourceName: "freeCodeCamp", estimatedMinutes: 12),
        ],
    ]

    static func links(for tag: String) -> [CuratedLink] {
        manifest[tag.lowercased()] ?? []
    }
}
