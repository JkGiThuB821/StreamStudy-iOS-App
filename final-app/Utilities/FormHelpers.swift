//
//  FormHelpers.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/10/2026.
//

import SwiftUI

// MARK: - Info button (Week 11 feedback: move descriptions behind ⓘ icons)

// A small ⓘ button that shows an explanation in a popover, so screens stay
// uncluttered while the help is still one tap away.
struct InfoButton: View {
    let title: String
    let message: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .expandedTapArea(by: 12)   // 44pt+ hit target, same look
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(title)")
        .accessibilityHint("Shows an explanation")
        .popover(isPresented: $isShowing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.sgHeadline)
                Text(message)
                    .font(.sgSubheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 360, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// A List section header with an ⓘ button beside the title.
struct InfoHeader: View {
    let title: String
    let info: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            InfoButton(title: title, message: info)
                .textCase(nil)
        }
    }
}

// MARK: - Input validation (Week 12 feedback)

// Maximum lengths for every text field in the app.
enum TextLimits {
    static let name = 40            // subject names, display names
    static let title = 80           // topic, resource and deadline titles
    static let shortDescription = 120
    static let longDescription = 500
    static let tag = 30
    static let url = 500
    static let email = 100
    static let password = 64
    static let notes = 1000
}

extension View {
    // Stops a text field from going past `limit` characters.
    func characterLimit(_ text: Binding<String>, _ limit: Int) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > limit {
                text.wrappedValue = String(newValue.prefix(limit))
            }
        }
    }

    // Keeps the last item in a scrolling screen clear of the custom tab bar
    // (Week 12 feedback: the Sign Out button was hidden behind it).
    func tabBarClearance() -> some View {
        contentMargins(.bottom, 96, for: .scrollContent)
    }
}

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
