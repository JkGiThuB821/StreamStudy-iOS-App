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
        "concurrency": [
            CuratedLink(title: "Concurrency — The Swift Programming Language", url: "https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/", sourceName: "Swift.org", estimatedMinutes: 25),
        ],
        "uikit": [
            CuratedLink(title: "UIKit documentation", url: "https://developer.apple.com/documentation/uikit", sourceName: "Apple Developer", estimatedMinutes: 20),
        ],
        "charts": [
            CuratedLink(title: "Swift Charts documentation", url: "https://developer.apple.com/documentation/charts", sourceName: "Apple Developer", estimatedMinutes: 15),
        ],
        "mapkit": [
            CuratedLink(title: "MapKit documentation", url: "https://developer.apple.com/documentation/mapkit", sourceName: "Apple Developer", estimatedMinutes: 15),
        ],
        "networking": [
            CuratedLink(title: "URLSession documentation", url: "https://developer.apple.com/documentation/foundation/urlsession", sourceName: "Apple Developer", estimatedMinutes: 15),
        ],
        "firebase": [
            CuratedLink(title: "Add Firebase to your Apple project", url: "https://firebase.google.com/docs/ios/setup", sourceName: "Firebase", estimatedMinutes: 15),
        ],
        "git": [
            CuratedLink(title: "Pro Git book", url: "https://git-scm.com/book/en/v2", sourceName: "git-scm.com", estimatedMinutes: 30),
        ],
        "python": [
            CuratedLink(title: "The Python Tutorial", url: "https://docs.python.org/3/tutorial/", sourceName: "Python.org", estimatedMinutes: 30),
        ],
        "javascript": [
            CuratedLink(title: "JavaScript Guide", url: "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide", sourceName: "MDN Web Docs", estimatedMinutes: 30),
        ],
    ]

    // Every tag the manifest has links for (given to Gemini so it can pick matching ones).
    static var knownTags: Set<String> {
        Set(manifest.keys)
    }

    static func links(for tag: String) -> [CuratedLink] {
        manifest[tag.lowercased()] ?? []
    }
}
