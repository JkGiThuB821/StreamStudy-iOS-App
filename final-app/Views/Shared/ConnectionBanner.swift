//
//  ConnectionBanner.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 14/10/2026.
//

import SwiftUI

// Shown at the top of the app: an orange bar while offline, and a brief
// green "Back online" bar when the connection returns. The offline bar has a
// Retry button and can be dismissed so it never stays in the way.
struct ConnectionBanner: View {
    @ObservedObject private var network = NetworkMonitor.shared
    @State private var showBackOnline = false
    @State private var isDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            if !network.isConnected && !isDismissed {
                offlineBanner
            } else if showBackOnline {
                banner("Back online", systemImage: "wifi", color: .green)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: network.isConnected)
        .animation(.easeInOut(duration: 0.25), value: showBackOnline)
        .animation(.easeInOut(duration: 0.25), value: isDismissed)
        .onChange(of: network.isConnected) { wasConnected, isConnected in
            AccessibilityNotification.Announcement(
                isConnected ? "Back online" : "You're offline"
            ).post()
            // Going offline again shows the bar again, even if it was dismissed.
            if !isConnected { isDismissed = false }

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

    private var offlineBanner: some View {
        HStack(spacing: 4) {
            Label("You're offline. Your saved subjects and resources still work.", systemImage: "wifi.slash")
                .font(.spaceGrotesk(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Retry") {
                network.recheck()
            }
            .font(.spaceGrotesk(size: 13, weight: .bold))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint("Checks the connection again")

            Button {
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hides the offline message")
        }
        .foregroundStyle(.black)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .transition(.move(edge: .top).combined(with: .opacity))
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
