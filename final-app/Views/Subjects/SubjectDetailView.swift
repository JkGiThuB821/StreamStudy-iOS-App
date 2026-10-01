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
    @State private var showingAddDeadline = false
    @State private var showingAddTopic = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: subject.iconName)
                            .font(.sgTitle)
                            .padding()
                            .background(Color(hex: subject.colorHex))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading) {
                            Text(subject.name).font(.spaceGrotesk(size: 22, weight: .bold))
                            Text(subject.subjectDescription)
                                .font(.sgSubheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        statBlock(value: "\(Int(subject.progress * 100))%", label: "Overall Progress")
                        statBlock(value: "\(subject.topics.filter { !$0.isCompleted }.count)", label: "Remaining")
                        statBlock(value: "\(subject.topics.count)", label: "Series")
                    }

                    Button {
                        showingAddDeadline = true
                    } label: {
                        Label("Add Deadline for \(subject.name)", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .listRowBackground(Color.clear)
            }

            Section("Series & Episodes") {
                ForEach(subject.topics.sorted { $0.orderIndex < $1.orderIndex }) { topic in
                    NavigationLink(value: topic) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title).font(.spaceGrotesk(size: 15, weight: .bold))
                            Text("\(topic.resources.count) episodes")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if subject.topics.isEmpty {
                    Text("No topics yet — tap + to add one.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(subject.name)
        .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddTopic = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddDeadline) {
            AddDeadlineView(subject: subject)
        }
        .sheet(isPresented: $showingAddTopic) {
            AddTopicView(subject: subject)
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.sgHeadline)
            Text(label).font(.sgCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
