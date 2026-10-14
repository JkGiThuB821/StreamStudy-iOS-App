//
//  SubjectsLibraryView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct SubjectsLibraryView: View {
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @State private var searchText = ""
    @State private var showingAddSubject = false

    private var filteredSubjects: [Subject] {
        guard !searchText.isEmpty else { return subjects }
        return subjects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var averageProgress: Int {
        guard !subjects.isEmpty else { return 0 }
        let avg = subjects.map(\.progress).reduce(0, +) / Double(subjects.count)
        return Int(avg * 100)
    }

    @ScaledMetric(relativeTo: .subheadline) private var cardMinWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .subheadline) private var cardHeight: CGFloat = 190

    // Adaptive columns: 2 in portrait, more in landscape / iPad, fewer at huge text sizes.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardMinWidth), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            statsHeader

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredSubjects) { subject in
                    NavigationLink(value: subject) {
                        subjectCard(subject)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showingAddSubject = true }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.sgTitle)
                        Text("Add Subject").font(.sgCaption)
                    }
                    .frame(maxWidth: .infinity, minHeight: cardHeight)
                    .background(Color.cardFill)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .searchable(text: $searchText, prompt: "Search subjects...")
        .background(Color.appBackground)
        .navigationTitle("Subjects Library")
        .navigationDestination(for: Subject.self) { SubjectDetailView(subject: $0) }
        .sheet(isPresented: $showingAddSubject) { AddSubjectView() }
    }

    private var statsHeader: some View {
        AdaptiveStack(horizontalAlignment: .center) {
            statBlock(value: "\(subjects.count)", label: "Subjects")
            statBlock(value: "\(subjects.filter { $0.progress > 0 && $0.progress < 1 }.count)", label: "In Progress")
            statBlock(value: "\(averageProgress)%", label: "Avg Progress")
        }
        .padding()
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.spaceGrotesk(size: 20, weight: .bold))
            Text(label).font(.sgCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func subjectCard(_ subject: Subject) -> some View {
        let resources = subject.topics.flatMap(\.resources)
        let minutesLeft = resources.filter { !$0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }
        let nextDeadline = subject.deadlines
            .filter { !$0.isOverdue }
            .min { $0.dueDate < $1.dueDate }
        let topicWord = subject.topics.count == 1 ? "topic" : "topics"
        let episodeWord = resources.count == 1 ? "episode" : "episodes"
        let contentSummary = "\(subject.topics.count) \(topicWord) Â· \(resources.count) \(episodeWord)"
        let deadlineIsClose = (nextDeadline?.daysRemaining ?? .max) <= 3

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: subject.iconName)
                    .font(.title3)
                Spacer()
                Text("\(Int(subject.progress * 100))%")
                    .font(.spaceGrotesk(size: 12, weight: .bold))
            }

            Text(subject.name)
                .font(.spaceGrotesk(size: 15, weight: .bold))
                .lineLimit(2)

            if !subject.subjectDescription.isEmpty {
                Text(subject.subjectDescription)
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            cardDetail(contentSummary, systemImage: "rectangle.stack")

            if minutesLeft > 0 {
                cardDetail("\(minutesLeft) min left to watch", systemImage: "clock")
            }

            cardDetail(deadlineText(nextDeadline), systemImage: "calendar")
                .fontWeight(deadlineIsClose ? .bold : .regular)

            ProgressView(value: subject.progress)
                .tint(.primary)
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int(subject.progress * 100)) percent")
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .background(Color(hex: subject.colorHex).opacity(0.55))
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func cardDetail(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.sgCaption2)
            .lineLimit(2)
    }

    private func deadlineText(_ deadline: Deadline?) -> String {
        guard let deadline else { return "No upcoming deadlines" }
        switch deadline.daysRemaining {
        case ...0: return "\(deadline.title) due today"
        case 1: return "\(deadline.title) due tomorrow"
        default: return "\(deadline.title) in \(deadline.daysRemaining) days"
        }
    }
}
