//
//  Theme.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import SwiftUI

// MARK: - Adaptive colours (Light & Dark Mode)

extension Color {
    // Pure black in Dark Mode, white in Light Mode.
    static let appBackground = Color(uiColor: .systemBackground)

    // Subtle card fill / outline that works on both backgrounds.
    static let cardFill = Color.primary.opacity(0.06)
    static let cardStroke = Color.primary.opacity(0.08)
}

// MARK: - Appearance setting

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Dynamic Type layout helper

// Lays children out horizontally, but stacks them vertically at the
// accessibility text sizes so nothing gets squashed or truncated.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))

        layout {
            content()
        }
    }
}
