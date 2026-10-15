//
//  NetworkMonitor.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 14/10/2026.
//

import Foundation
import Network
import Combine

// Publishes whether the device currently has an internet connection, so views
// can show the offline banner and skip features that need the network.
@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: DispatchQueue(label: "StreamStudy.NetworkMonitor"))
    }
}
