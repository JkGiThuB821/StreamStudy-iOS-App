//
//  SubjectDetailView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct SubjectDetailView: View {
    @Bindable var subject: Subject
    @Query private var digests: [WeeklyDigest]
    @State private var showingAddDeadline = false
    @State private var showingAddTopic = false
    @State private var recap: SeasonRecap?

    @ScaledMetric(relativeTo: .title) private var iconTileSize: CGFloat = 58

    private var sortedTopics: [Topic] {
        subject.topics.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var episodes: [LearningResource] { subject.topics.flatMap(\.resources) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                AdaptiveStack(horizontalAlignment: .center, spacing: 10) {
                    StatBox(value: "\(Int(subject.progress * 100))%", label: "Overall Progress", color: .red)
                    StatBox(value: "\(episodes.filter(\.isCompleted).count)/\(episodes.count)", label: "Episodes Done", color: .green)
                    StatBox(value: "\(subject.topics.count)", label: "Series")
                }

                ProgressView(value: subject.progress)
                    .tint(.red)
                    .accessibilityLabel("Overall progress")

                Button {
                    showingAddDeadline = true
                } label: {
                    Label("Add Deadline for \(subject.name)", systemImage: "plus")
                }
                .buttonStyle(OutlineButtonStyle())

                // Season Pass finale: built fresh each time from the signal pipeline.
                Button {
                    recap = SeasonRecapBuilder.build(for: subject, digests: digests)
                } label: {
                    Label("Season Recap", systemImage: "play.rectangle.on.rectangle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("Series & Episodes")
                    .font(.spaceGrotesk(size: 20, weight: .bold, relativeTo: .title3))
                    .padding(.top, 6)

                topicList
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddTopic = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add topic")
            }
        }
        .fullScreenCover(item: $recap) { recap in
            SeasonRecapView(recap: recap)
        }
        .sheet(isPresented: $showingAddDeadline) {
            AddDeadlineView(subject: subject)
        }
        .sheet(isPresented: $showingAddTopic) {
            AddTopicView(subject: subject)
        }
    }

    private var header: some View {
        AdaptiveStack(spacing: 14) {
            Image(systemName: subject.iconName)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: iconTileSize, height: iconTileSize)
                .background(Color(hex: subject.colorHex), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.spaceGrotesk(size: 24, weight: .bold, relativeTo: .title2))
                if !subject.subjectDescription.isEmpty {
                    Text(subject.subjectDescription)
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Topics ("episodes" of the series) in one card, numbered, with status and length.
    private var topicList: some View {
        VStack(spacing: 0) {
            if sortedTopics.isEmpty {
                Text("No topics yet: tap + to add one.")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            ForEach(Array(sortedTopics.enumerated()), id: \.element.id) { index, topic in
                if index > 0 { Divider().padding(.leading, 36) }

                NavigationLink(value: topic) {
                    topicRow(topic, number: index + 1)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    private func topicRow(_ topic: Topic, number: Int) -> some View {
        let status = TopicStatus(topic)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .font(.subheadline)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(topic.title)")
                    .font(.spaceGrotesk(size: 15, weight: .bold))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Text(status.label)
                        .font(.spaceGrotesk(size: 12, weight: .bold))
                        .foregroundStyle(status.color)
                    Label("\(topic.totalDurationMinutes) min", systemImage: "clock")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

// Complete / In Progress / Not Started, as shown in the mock-up's episode list.
private struct TopicStatus {
    let label: String
    let symbol: String
    let color: Color

    init(_ topic: Topic) {
        if topic.isCompleted {
            (label, symbol, color) = ("Complete", "circle.fill", .green)
        } else if topic.progress > 0 {
            (label, symbol, color) = ("In Progress", "circle.lefthalf.filled", .orange)
        } else {
            (label, symbol, color) = ("Not Started", "circle", .secondary)
        }
    }
}
