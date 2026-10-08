//
//  DeepLinkRouterTests.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 8/10/2026.
//

import Foundation
import Testing
@testable import final_app

@MainActor
@Suite("Deep linking")
struct DeepLinkRouterTests {

    @Test("Topic link opens that topic")
    func topicLink() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.handle(url: URL(string: "streamstudy://topic/\(id.uuidString)")!)
        #expect(router.destination == .topic(id))
    }

    @Test("Calendar link with a deadline ID selects that deadline")
    func calendarLinkWithID() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.handle(url: URL(string: "streamstudy://calendar/\(id.uuidString)")!)
        #expect(router.destination == .calendar(id))
    }

    @Test("Calendar link without an ID still opens the calendar")
    func calendarLinkWithoutID() {
        let router = DeepLinkRouter()
        router.handle(url: URL(string: "streamstudy://calendar")!)
        #expect(router.destination == .calendar(nil))
    }

    @Test("Unexpected links are ignored", arguments: [
        "https://example.com/topic/123",          // wrong scheme
        "streamstudy://topic/not-a-uuid",          // malformed ID
        "streamstudy://topic",                     // missing ID
        "streamstudy://settings/abc",              // unknown destination
    ])
    func invalidLinksAreIgnored(link: String) {
        let router = DeepLinkRouter()
        router.handle(url: URL(string: link)!)
        #expect(router.destination == nil)
    }

    @Test("clear() resets the destination so a link doesn't fire twice")
    func clearResets() {
        let router = DeepLinkRouter()
        router.handle(url: URL(string: "streamstudy://calendar")!)
        router.clear()
        #expect(router.destination == nil)
    }
}
