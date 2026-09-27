//
//  HomeView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]
    @Query private var subjects: [Subject]

    private var inProgressTopics: [Topic] {
        subjects
            .flatMap(\.topics)
            .filter { !$0.isCompleted && $0.progress > 0 }
    }

    private var upcomingDeadlines: [Deadline] {
        deadlines.filter { !$0.isOverdue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let nextDeadline = upcomingDeadlines.first {
                    nextWatchCard(for: nextDeadline)
                }

                sectionRow(title: "Continue Learning", badge: "IN PROGRESS", topics: inProgressTopics)

                if !upcomingDeadlines.isEmpty {
                    dueSoonRow
                }

                if inProgressTopics.isEmpty && upcomingDeadlines.isEmpty {
                    ContentUnavailableView(
                        "Nothing yet",
                        systemImage: "sparkles.tv",
                        description: Text("Add a subject to start building your home feed.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .navigationTitle("Home")
        .toolbarBackground(.black, for: .navigationBar)
    }

    private func nextWatchCard(for deadline: Deadline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NEXT WATCH")
                .font(.caption.bold())
                .foregroundStyle(.red)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text(deadline.subject?.name ?? deadline.title)
                    .font(.title3.bold())
                Text(deadline.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Label("Continue", systemImage: "play.fill")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                    Label("More Info", systemImage: "info.circle")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .font(.subheadline.bold())
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.red.opacity(0.4), .black], startPoint: .top, endPoint: .bottom)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func sectionRow(title: String, badge: String?, topics: [Topic]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(topics) { topic in
                        topicCard(topic)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var dueSoonRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Due Soon").font(.headline).foregroundStyle(.white).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingDeadlines.prefix(5)) { deadline in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEADLINE")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                            Text(deadline.subject?.name ?? deadline.title)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text("\(deadline.daysRemaining) days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: 140, alignment: .leading)
                        .background(.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func topicCard(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text(topic.subject?.name ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(topic.title)
                .font(.subheadline.bold())
                .lineLimit(2)
            ProgressView(value: topic.progress)
                .tint(.red)
        }
        .padding(10)
        .frame(width: 150, height: 110, alignment: .leading)
        .background(Color(hex: topic.subject?.colorHex ?? "#333333").opacity(0.5))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
