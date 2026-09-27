//
//  LearningResource.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 27/9/2026.
//

import Foundation
import SwiftData

enum ResourceType: String, Codable, CaseIterable {
    case video
    case article
    case documentation
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .article: return "Article"
        case .documentation: return "Documentation"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .article: return "doc.text.fill"
        case .documentation: return "book.fill"
        }
    }
}

enum ResourceLength: String, Codable {
    case short
    case episode
    
    static func classify(minutes: Int) -> ResourceLength {
        minutes < 5 ? .short: .episode
    }
}

@Model
final class LearningResource {
    var id: UUID
    var title: String
    var resourceDescription: String
    var urlString: String
    var thumbnailURLString: String?
    var sourceName: String
    var type: ResourceType
    var durationMiuntes: Int
    var isCompleted: Bool
    var isSaved: Bool
    var addedAt: Date
    
    var topic: Topic?
    
    init(
        title: String,
        urlString: String,
        sourceName: String,
        type: ResourceType,
        durationMinutes: Int,
        resouceDescription: String = "",
        thumbnailURLString: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.resourceDescription = resouceDescription
        self.urlString = urlString
        self.thumbnailURLString = thumbnailURLString
        self.sourceName = sourceName
        self.type = type
        self.durationMiuntes = durationMinutes
        self.isCompleted = false
        self.isSaved = false
        self.addedAt = .now
    }
    
    var lengthCategory: ResourceLength {
        ResourceLength.classify(minutes: durationMiuntes)
    }
}
