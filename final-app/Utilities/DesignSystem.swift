//
//  DesignSystem.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/10/2026.
//

import SwiftUI

// Shared building blocks that match the UI design proposal's mock-ups
// (bordered stat boxes, progress rings, red badges, red action buttons,
// filled input fields), so every screen uses the same look.

// MARK: - Cards

extension View {
    // A rounded card with a subtle fill and border.
    func cardStyle(cornerRadius: CGFloat = 14) -> some View {
        background(Color.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.cardStroke, lineWidth: 1))
    }

    // A filled input field, as used in the proposal's sheets and sign-in card.
    func inputFieldStyle() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardStroke, lineWidth: 1))
    }
}

// MARK: - Touch targets

extension View {
    // HIG: controls need a hit target of at least 44×44 pt. This grows the
    // tappable area around a small control without changing how it looks or
    // how much space it takes up in the layout.
    func expandedTapArea(_ edges: Edge.Set = .all, by amount: CGFloat = 10) -> some View {
        padding(edges, amount)
            .contentShape(Rectangle())
            .padding(edges, -amount)
    }
}

// MARK: - Stat box

// A bordered box with a large coloured number and a small caption.
struct StatBox: View {
    let value: String
    let label: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.spaceGrotesk(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .cardStyle(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    var color: Color = .red
    var lineWidth: CGFloat = 5
    var showsLabel = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text("\(Int(progress * 100))%")
                    .font(.spaceGrotesk(size: 11, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .padding(lineWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - Badge

// A small filled uppercase label, e.g. "YOUR NEXT WATCH", "DEADLINE", "HIGH".
struct BadgeLabel: View {
    let text: String
    var color: Color = .red
    var filled = true

    var body: some View {
        Text(text.uppercased())
            .font(.spaceGrotesk(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(filled ? Color.white : color)
    }
}

// MARK: - Buttons

// Full-width red button for a screen's main action (Sign In, Add Deadline…).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spaceGrotesk(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
    }
}

// Full-width red outline button for secondary actions (+ Add Deadline for …).
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spaceGrotesk(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.red)
            .background(Color.red.opacity(configuration.isPressed ? 0.15 : 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.6), lineWidth: 1))
    }
}

// A red pill segmented control (Sign In / Create Account, Profile / Notifications).
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let (value, title) = options[index]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = value }
                } label: {
                    Text(title)
                        .font(.spaceGrotesk(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == value ? Color.red : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .expandedTapArea(.vertical, by: 4)
                        .foregroundStyle(selection == value ? Color.white : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Screen header

// The large title + grey subtitle used at the top of each tab in the mock-ups.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.spaceGrotesk(size: 32, weight: .bold, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Deadline helpers

extension DeadlinePriority {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

extension Subject {
    // The soonest deadline that isn't overdue.
    var nextDeadline: Deadline? {
        deadlines.filter { !$0.isOverdue }.min { $0.dueDate < $1.dueDate }
    }
}

extension Deadline {
    // "DUE OCT 14"
    var shortDueLabel: String {
        "Due \(dueDate.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
