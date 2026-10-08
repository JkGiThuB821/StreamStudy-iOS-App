//
//  TestSupport.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//
//  Shared helpers: an in-memory SwiftData store and a URLProtocol stub so
//  API calls can be tested without the network or real API keys.
//

import Foundation
import SwiftData
@testable import final_app

// MARK: - In-memory SwiftData

@MainActor
func makeTestContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Subject.self, Topic.self, LearningResource.self, Deadline.self, StudyProgress.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
func makeTopic(
    in context: ModelContext,
    title: String = "Relationships",
    description: String = "",
    subjectName: String = "iOS Development"
) -> Topic {
    let subject = Subject(name: subjectName)
    context.insert(subject)
    let topic = Topic(title: title, topicDescription: description)
    topic.subject = subject
    context.insert(topic)
    return topic
}

@MainActor
@discardableResult
func addResource(
    to topic: Topic,
    in context: ModelContext,
    title: String,
    type: ResourceType,
    minutes: Int
) -> LearningResource {
    let resource = LearningResource(
        title: title,
        urlString: "https://example.com/\(UUID().uuidString)",
        sourceName: "Test",
        type: type,
        durationMinutes: minutes
    )
    resource.topic = topic
    context.insert(resource)
    return resource
}

// MARK: - Network stub

// Intercepts every request made through `StubURLProtocol.session` and answers
// it with whatever `handler` returns, so tests control the "API response".
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let (status, data) = Self.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension String {
    var utf8Data: Data { Data(utf8) }
}
