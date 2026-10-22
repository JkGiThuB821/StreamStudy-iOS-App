//
//  WeeklyDigestView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import SwiftUI
import SwiftData
import Charts

// "This Week's Episodes": the Weekly Digest sheet. Shows last week's study
// time, then each featured topic as a Swipe-to-Revise card.
struct WeeklyDigestView: View {
    let digest: WeeklyDigest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var allTopics: [Topic]
    @Query private var progress: [StudyProgress]

    private var featuredTopics: [Topic] {
        WeeklyDigestService.topics(in: digest, from: allTopics)
    }

    private var lastWeekDays: [DayMinutes] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset -> DayMinutes? in
            guard let day = calendar.date(byAdding: .day, value: offset - 7, to: digest.weekStart) else { return nil }
            let minutes = progress
                .filter { calendar.isDate($0.date, inSameDayAs: day) && $0.minutesSpent > 0 }
                .reduce(0) { $0 + $1.minutesSpent }
            return DayMinutes(date: day, minutes: minutes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    lastWeekCard

                    if featuredTopics.isEmpty {
                        ContentUnavailableView(
                            "No episodes yet",
                            systemImage: "sparkles.tv",
                            description: Text("Add topics to a subject and next week's drop will feature them.")
                        )
                    } else {
                        Text("THIS WEEK'S EPISODES")
                            .font(.spaceGrotesk(size: 13, weight: .bold))
                            .foregroundStyle(.red)

                        ForEach(Array(featuredTopics.enumerated()), id: \.element.id) { index, topic in
                            episodeCard(topic, number: index + 1)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("Weekly Digest")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header and stats

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Week of \(digest.weekStart.formatted(.dateTime.day().month(.wide)))")
                .font(.sgCaption)
                .foregroundStyle(.secondary)
            Text(digest.headline)
                .font(.spaceGrotesk(size: 22, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lastWeekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdaptiveStack(spacing: 16) {
                stat("\(digest.minutesLastWeek)", "minutes studied last week")
                stat("\(digest.episodesLastWeek)", digest.episodesLastWeek == 1 ? "episode finished" : "episodes finished")
            }

            Chart(lastWeekDays) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Minutes", day.minutes)
                )
                .foregroundStyle(Color.red.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 110)
            .accessibilityLabel("Minutes studied each day last week")
        }
        .padding()
        .background(Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.spaceGrotesk(size: 24, weight: .bold))
            Text(label).font(.sgCaption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Episode cards

    private func episodeCard(_ topic: Topic, number: Int) -> some View {
        let episode = WeeklyDigestService.episode(for: topic, in: digest)

        return SwipeToReviseCard(currentRating: topic.difficulty) { rating in
            SignalPipeline.recordRating(rating, for: topic, resource: episode, source: .digest, in: modelContext)
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("EPISODE \(number) · \(topic.subject?.name ?? "")")
                    .font(.spaceGrotesk(size: 11, weight: .bold))
                    .foregroundStyle(.red)

                Text(topic.title)
                    .font(.spaceGrotesk(size: 18, weight: .bold))

                if let episode {
                    episodeRow(episode)
                } else {
                    Text("No episode picked yet: find resources for this topic.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }

                NavigationLink(value: topic) {
                    Label("Open topic", systemImage: "chevron.right")
                        .font(.spaceGrotesk(size: 13, weight: .semibold))
                }
            }
        }
    }

    private func episodeRow(_ episode: LearningResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if let url = URL(string: episode.urlString) { openURL(url) }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.spaceGrotesk(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text("\(episode.sourceName) · \(episode.durationMinutes) min")
                            .font(.sgCaption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: episode.type.sfSymbol).foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)

            if !episode.aiTags.isEmpty {
                Text("Picked for: \(episode.aiTags.joined(separator: " · "))")
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DayMinutes: Identifiable {
    let date: Date
    let minutes: Int
    var id: Date { date }
}

// MARK: - Home teaser

// The "new episodes have dropped" card at the top of Home.
struct WeeklyDigestCard: View {
    let digest: WeeklyDigest
    let featuredCount: Int
    let ratedCount: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("NEW EPISODES")
                        .font(.spaceGrotesk(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    Spacer()
                    Text("Week of \(digest.weekStart.formatted(.dateTime.day().month()))")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }

                Text("This Week's Episodes")
                    .font(.spaceGrotesk(size: 20, weight: .bold))

                Text(digest.headline)
                    .font(.sgSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if featuredCount > 0 {
                    ProgressView(value: Double(ratedCount), total: Double(featuredCount))
                        .tint(.red)
                    Text("\(ratedCount) of \(featuredCount) rated this week")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.red.opacity(0.3), Color.cardFill], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this week's digest")
    }
}
