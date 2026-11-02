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

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "StreamStudy.NetworkMonitor")
    private var probeTask: Task<Void, Never>?

    private init() {
        startMonitor()
    }

    // Checks the connection again from scratch: restarts the path monitor and
    // tries a real request. Called when the app becomes active and from the
    // banner's Retry button, because the monitor can get stuck on "offline"
    // (common in the Simulator after the Mac's Wi-Fi changes).
    func recheck() {
        startMonitor()
        probe()
    }

    // A cancelled NWPathMonitor can't be restarted, so a new one is made each time.
    private func startMonitor() {
        monitor?.cancel()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.pathChanged(connected: connected)
            }
        }
        monitor.start(queue: queue)
        self.monitor = monitor
    }

    // "Online" is trusted straight away. "Offline" is confirmed with a real
    // request first, so a stale path status can't leave the app stuck offline.
    private func pathChanged(connected: Bool) {
        if connected {
            probeTask?.cancel()
            isConnected = true
        } else {
            probe()
        }
    }

    private func probe() {
        probeTask?.cancel()
        probeTask = Task {
            guard let url = URL(string: "https://www.google.com/generate_204") else { return }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            request.httpMethod = "HEAD"
            let reachable = (try? await URLSession.shared.data(for: request)) != nil
            guard !Task.isCancelled else { return }
            isConnected = reachable
        }
    }
}
