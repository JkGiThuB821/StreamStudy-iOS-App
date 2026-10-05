//
//  DeepLinkRouter.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 5/10/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {

    enum Destination: Equatable {
        case topic(UUID)
        case calendar(UUID?)
    }

    @Published var destination: Destination?

    func handle(url: URL) {
        guard url.scheme == "streamstudy" else { return }

        let components = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "topic":
            if let id = components.first.flatMap(UUID.init(uuidString:)) {
                destination = .topic(id)
            }
        case "calendar":
            let id = components.first.flatMap(UUID.init(uuidString:))
            destination = .calendar(id)
        default:
            break
        }
    }

    func clear() {
        destination = nil
    }
}
