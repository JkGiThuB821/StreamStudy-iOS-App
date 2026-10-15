//
//  ConnectionBanner.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 14/10/2026.
//


import SwiftUI

// Shown at the top of the app: an orange bar while offline, and a brief
// green "Back online" bar when the connection returns.
struct ConnectionBanner: View {
    @ObservedObject private var network = NetworkMonitor.shared
    @State private var showBackOnline = false

    var body: some View {
        VStack(spacing: 0) {
            if !network.isConnected {
                banner(
                    "You're offline. Your saved subjects and resources still work.",
                    systemImage: "wifi.slash",
                    color: .orange
                )
            } else if showBackOnline {
                banner("Back online", systemImage: "wifi", color: .green)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: network.isConnected)
        .animation(.easeInOut(duration: 0.25), value: showBackOnline)
        .onChange(of: network.isConnected) { wasConnected, isConnected in
            AccessibilityNotification.Announcement(
                isConnected ? "Back online" : "You're offline"
            ).post()

            guard isConnected, !wasConnected else {
                showBackOnline = false
                return
            }
            showBackOnline = true
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                showBackOnline = false
            }
        }
    }

    private func banner(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.spaceGrotesk(size: 13, weight: .semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(color)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
