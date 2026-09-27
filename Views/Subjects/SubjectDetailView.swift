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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: subject.iconName)
                            .font(.title)
                            .padding()
                            .background(Color(hex: subject.colorHex))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading) {
                            Text(subject.name).font(.title2.bold())
                            Text(subject.subjectDescription)
                                .font(.subheadline)
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
                            Text(topic.title).font(.subheadline.bold())
                            Text("\(topic.resources.count) episodes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(subject.name)
        .navigationDestination(for: Topic.self) { TopicDetailPlaceholderView(topic: $0) }
        .sheet(isPresented: $showingAddDeadline) {
            AddDeadlineView(subject: subject)
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TopicDetailPlaceholderView: View {
    let topic: Topic

    var body: some View {
        List {
            ForEach(topic.resources) { resource in
                Label(resource.title, systemImage: resource.type.sfSymbol)
            }
        }
        .navigationTitle(topic.title)
        .overlay {
            if topic.resources.isEmpty {
                ContentUnavailableView(
                    "No resources yet",
                    systemImage: "play.rectangle",
                    description: Text("Resource discovery is added in Stage 3.")
                )
            }
        }
    }
}
