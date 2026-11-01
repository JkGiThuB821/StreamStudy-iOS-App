//
//  SwipeToReviseCard.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import SwiftUI

// Swipe-to-Revise (Season Pass): swipe right = "Got it", swipe left = "Needs
// revision". The two buttons underneath do exactly the same thing, so the
// feature is fully usable without gestures (VoiceOver, Switch Control, or
// anyone who prefers tapping). Used on topic screens and Weekly Digest cards.
struct SwipeToReviseCard<Content: View>: View {
    let currentRating: DifficultyRating
    let onRate: (DifficultyRating) -> Void
    // Compact = the UI proposal's resource card: the two rating buttons sit
    // inside the card as a split bar, with no badge or hint text.
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var feedbackTrigger = 0
    @State private var lastRating: DifficultyRating = .notRated

    // How far the card must travel (or be flicked) to count as a rating.
    private let threshold: CGFloat = 110

    private var swipeProgress: Double {
        min(abs(offset) / threshold, 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                swipeHints
                card
            }

            if !compact {
                buttons
            }
        }
        .sensoryFeedback(trigger: feedbackTrigger) { _, _ in
            lastRating == .understood ? .success : .warning
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 10) {
            if compact {
                content()
                    .padding(12)
                Divider()
                compactBar
            } else {
                content()

                ratingBadge

                if !reduceMotion {
                    Text("Swipe right if you've got it, left if you need to revise.")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 0 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque base so the swipe hints behind the card stay hidden until it moves.
        .background(Color.cardFill)
        .background(Color.appBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: offset == 0 ? 1 : 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .offset(x: offset)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 25)))
        // Simultaneous + horizontal-only, so vertical scrolling in a List or
        // ScrollView keeps working while the card is being swiped.
        .simultaneousGesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityValue(ratingDescription)
        .accessibilityHint("Swipe right if you understand this, left if it needs revision, or use the buttons below.")
        .accessibilityAction(named: "Got it") { rate(.understood) }
        .accessibilityAction(named: "Needs revision") { rate(.needsRevision) }
    }

    private var ratingDescription: String {
        switch currentRating {
        case .understood: return "Rated got it"
        case .needsRevision: return "Rated needs revision"
        case .notRated: return "Not rated yet"
        }
    }

    private var borderColor: Color {
        if offset > 0 { return Color.green.opacity(swipeProgress) }
        if offset < 0 { return Color.orange.opacity(swipeProgress) }
        return Color.cardStroke
    }

    @ViewBuilder
    private var ratingBadge: some View {
        switch currentRating {
        case .understood:
            Label("Got it", systemImage: "checkmark.circle.fill")
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .foregroundStyle(.green)
        case .needsRevision:
            Label("Needs revision", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .foregroundStyle(.orange)
        case .notRated:
            Label("Not rated yet", systemImage: "circle.dashed")
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    // Revealed behind the card as it moves.
    private var swipeHints: some View {
        HStack {
            Label("Got it", systemImage: "checkmark")
                .foregroundStyle(.green)
                .opacity(offset > 0 ? swipeProgress : 0)
            Spacer()
            Label("Revise", systemImage: "arrow.uturn.backward")
                .foregroundStyle(.orange)
                .opacity(offset < 0 ? swipeProgress : 0)
        }
        .font(.spaceGrotesk(size: 15, weight: .bold))
        .padding(.horizontal, 20)
        .accessibilityHidden(true)
    }

    // The proposal's "← Needs Revision | Understood →" split bar.
    private var compactBar: some View {
        HStack(spacing: 0) {
            compactButton("← Needs Revision", rating: .needsRevision, color: .orange)
            Divider()
            compactButton("Understood →", rating: .understood, color: .green)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func compactButton(_ title: String, rating: DifficultyRating, color: Color) -> some View {
        let isCurrent = currentRating == rating
        return Button {
            rate(rating)
        } label: {
            Text(title)
                .font(.spaceGrotesk(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundStyle(isCurrent ? color : Color.secondary)
                .background(isCurrent ? color.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rating == .understood ? "Understood" : "Needs revision")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: - Accessible equivalent

    private var buttons: some View {
        HStack(spacing: 12) {
            ratingButton("Needs revision", systemImage: "arrow.uturn.backward", rating: .needsRevision, color: .orange)
            ratingButton("Got it", systemImage: "checkmark", rating: .understood, color: .green)
        }
    }

    private func ratingButton(_ title: String, systemImage: String, rating: DifficultyRating, color: Color) -> some View {
        Button {
            rate(rating)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.spaceGrotesk(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .accessibilityAddTraits(currentRating == rating ? .isSelected : [])
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Only follow mostly-horizontal drags; vertical ones are scrolling.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = value.translation.width
            }
            .onEnded { value in
                let flicked = abs(value.predictedEndTranslation.width) > threshold * 1.6 && abs(offset) > 40
                if offset > threshold || (flicked && offset > 0) {
                    rate(.understood)
                } else if offset < -threshold || (flicked && offset < 0) {
                    rate(.needsRevision)
                } else {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
    }

    private func rate(_ rating: DifficultyRating) {
        lastRating = rating
        feedbackTrigger += 1
        onRate(rating)

        guard !reduceMotion else {
            offset = 0
            return
        }

        // Fly off in the swiped direction, then spring back showing the new rating.
        withAnimation(.easeIn(duration: 0.18)) {
            offset = rating == .understood ? 420 : -420
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            offset = rating == .understood ? -60 : 60
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                offset = 0
            }
        }
    }
}
