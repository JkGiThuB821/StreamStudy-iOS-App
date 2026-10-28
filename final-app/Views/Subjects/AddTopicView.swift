//
//  AddTopicView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct AddTopicView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var subject: Subject

    @State private var title = ""
    @State private var description = ""
    @State private var searchTag = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("New Topic") {
                    TextField("Topic title (e.g. SwiftData Relationships)", text: $title)
                        .characterLimit($title, TextLimits.title)
                }

                Section {
                    TextField(
                        "e.g. Assignment 2: model a one-to-many relationship and query it with #Predicate",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .characterLimit($description, TextLimits.longDescription)
                } header: {
                    InfoHeader(
                        title: "What do you need to learn?",
                        info: "Be specific. The description is used to find relevant videos, articles and docs, and to build your step-by-step lesson plan."
                    )
                }

                Section {
                    TextField("e.g. swift, swiftui, ios, algorithms", text: $searchTag)
                        .textInputAutocapitalization(.never)
                        .characterLimit($searchTag, TextLimits.tag)
                } header: {
                    InfoHeader(
                        title: "Search tag (optional)",
                        info: "Used to find dev.to articles and curated docs for this topic. Leave blank to guess one from the title."
                    )
                }
            }
            .font(.sgBody)
            .navigationTitle("Add Topic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTopic() }
                        .disabled(title.isBlank)
                }
            }
        }
    }

    private func addTopic() {
        let topic = Topic(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            topicDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            orderIndex: subject.topics.count,
            searchTag: searchTag.trimmingCharacters(in: .whitespaces)
        )
        topic.subject = subject
        modelContext.insert(topic)
        dismiss()
    }
}

