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
    @ScaledMetric(relativeTo: .subheadline) private var cardHeight: CGFloat = 200
    @ScaledMetric(relativeTo: .subheadline) private var ringSize: CGFloat = 38

    // Adaptive columns: 2 in portrait, more in landscape / iPad, fewer at huge text sizes.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardMinWidth), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsHeader

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredSubjects) { subject in
                        NavigationLink(value: subject) {
                            subjectCard(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if subjects.isEmpty {
                    ContentUnavailableView(
                        "No subjects yet",
                        systemImage: "square.grid.2x2",
                        description: Text("Tap + to add your first subject.")
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .searchable(text: $searchText, prompt: "Search subjects...")
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        // Floating add button, as in the mock-up.
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingAddSubject = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red, in: Circle())
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
            .accessibilityLabel("Add subject")
            .padding(.trailing, 20)
            .padding(.bottom, 84)   // sits above the tab bar
        }
        .navigationTitle("Subjects Library")
        .navigationDestination(for: Subject.self) { SubjectDetailView(subject: $0) }
        .sheet(isPresented: $showingAddSubject) { AddSubjectView() }
    }

    private var statsHeader: some View {
        AdaptiveStack(horizontalAlignment: .center, spacing: 10) {
            StatBox(value: "\(subjects.count)", label: "Subjects")
            StatBox(value: "\(subjects.filter { $0.progress > 0 && $0.progress < 1 }.count)", label: "In Progress")
            StatBox(value: "\(averageProgress)%", label: "Avg Progress")
        }
    }

    private func subjectCard(_ subject: Subject) -> some View {
        let color = Color(hex: subject.colorHex)
        let resources = subject.topics.flatMap(\.resources)
        let topicWord = subject.topics.count == 1 ? "topic" : "topics"
        let episodeWord = resources.count == 1 ? "episode" : "episodes"
        // The dot is written as \u{00B7} so the file stays plain ASCII and the
        // character can't get mangled when the file is copied between computers.
        let contentSummary = "\(subject.topics.count) \(topicWord) \u{00B7} \(resources.count) \(episodeWord)"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: subject.iconName)
                    .font(.title)
                    .foregroundStyle(color)
                Spacer()
                ProgressRing(progress: subject.progress, color: color, lineWidth: 4)
                    .frame(width: ringSize, height: ringSize)
            }

            Text(subject.name)
                .font(.spaceGrotesk(size: 16, weight: .bold))
                .lineLimit(2)

            if !subject.subjectDescription.isEmpty {
                Text(subject.subjectDescription)
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(contentSummary)
                .font(.sgCaption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let deadline = subject.nextDeadline {
                BadgeLabel(text: deadline.shortDueLabel, color: .red, filled: false)
            }
        }
        .padding(12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        // Coloured progress strip along the bottom edge.
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.width * subject.progress, 0), height: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.45), lineWidth: 1))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(subject.progress * 100)) percent complete")
    }
}
