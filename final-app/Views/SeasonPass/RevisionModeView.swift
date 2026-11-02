//
//  RevisionModeView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import SwiftUI
import SwiftData

// Revision Mode: a focused session that deals out the topics needing the most
// attention, one at a time, to rate with Swipe-to-Revise. Every rating goes
// into the same signal pipeline as the topic screen and the Weekly Digest.
struct RevisionModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var topics: [Topic]

    @State private var deck: [Topic] = []
    @State private var index = 0
    @State private var ratedCount = 0
    @State private var revisionCount = 0

    // Topics most in need of revision first; unrated ones count as uncertain.
    // Topics already rated "got it" are left out, so a finished session doesn't
    // start over. `includeAll` is the "review everything anyway" option.
    private static func makeDeck(from topics: [Topic], includeAll: Bool = false) -> [Topic] {
        let open = topics.filter { !$0.isCompleted }
        let pool = open.isEmpty ? topics : open
        let sorted = pool.sorted { SignalPipeline.difficultySignal(for: $0) > SignalPipeline.difficultySignal(for: $1) }
        return includeAll ? sorted : sorted.filter { SignalPipeline.difficultySignal(for: $0) >= 0.5 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if topics.isEmpty {
                    ContentUnavailableView(
                        "Nothing to revise yet",
                        systemImage: "rectangle.stack",
                        description: Text("Add topics to a subject to start a revision session.")
                    )
                } else if deck.isEmpty {
                    allCaughtUp
                } else if index < deck.count {
                    progressHeader
                    topicCard(deck[index])
                        .id(deck[index].id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    Spacer(minLength: 0)
                    Button("Skip this topic") { advance() }
                        .font(.spaceGrotesk(size: 14, weight: .semibold))
                } else {
                    summary
                }
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .navigationTitle("Revision Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if deck.isEmpty { deck = Self.makeDeck(from: topics) }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Topic \(index + 1) of \(deck.count)")
                .font(.sgCaption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(index), total: Double(deck.count))
                .tint(.red)
        }
    }

    private func topicCard(_ topic: Topic) -> some View {
        let episode = SignalPipeline.bestEpisode(for: topic)

        return SwipeToReviseCard(currentRating: topic.difficulty) { rating in
            SignalPipeline.recordRating(rating, for: topic, resource: episode, source: .revision, in: modelContext)
            ratedCount += 1
            if rating == .needsRevision { revisionCount += 1 }
            advance(afterSwipe: true)
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.subject?.name.uppercased() ?? "")
                    .font(.spaceGrotesk(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                Text(topic.title)
                    .font(.spaceGrotesk(size: 22, weight: .bold))
                if !topic.topicDescription.isEmpty {
                    Text(topic.topicDescription)
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                if let episode {
                    Button {
                        if let url = URL(string: episode.urlString) { openURL(url) }
                    } label: {
                        Label("Quick refresher: \(episode.title)", systemImage: episode.type.sfSymbol)
                            .font(.spaceGrotesk(size: 13, weight: .semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // Every topic is rated "got it": say so instead of dealing them all again.
    private var allCaughtUp: some View {
        ContentUnavailableView {
            Label("All caught up", systemImage: "checkmark.seal.fill")
        } description: {
            Text("You've rated every topic as understood. Rate a topic \"Needs Revision\" and it will come up here.")
        } actions: {
            Button("Review All Topics Anyway") { startSession(includeAll: true) }
                .buttonStyle(.bordered)
                .tint(.red)
        }
    }

    private var summary: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Session complete")
                .font(.sgTitle2)
            Text(ratedCount == 0
                 ? "You skipped every topic this time."
                 : "You rated \(ratedCount) topic\(ratedCount == 1 ? "" : "s"). \(revisionCount) still need\(revisionCount == 1 ? "s" : "") revision and will come up first on Home.")
                .font(.sgBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            // Starts a new session with the topics that still need revision.
            if revisionCount > 0 {
                Button("Revise Again") { startSession() }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func startSession(includeAll: Bool = false) {
        deck = Self.makeDeck(from: topics, includeAll: includeAll)
        index = 0
        ratedCount = 0
        revisionCount = 0
    }

    // After a swipe, wait for the card's fly-off before showing the next topic.
    private func advance(afterSwipe: Bool = false) {
        Task {
            if afterSwipe && !reduceMotion {
                try? await Task.sleep(for: .milliseconds(350))
            }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                index += 1
            }
        }
    }
}
