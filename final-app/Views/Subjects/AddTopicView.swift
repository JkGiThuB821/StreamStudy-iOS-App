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
                }

                Section {
                    TextField(
                        "e.g. Assignment 2: model a one-to-many relationship and query it with #Predicate",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } header: {
                    Text("What do you need to learn?")
                } footer: {
                    Text("Be specific. The description is used to find relevant videos, articles and docs, and to build your step-by-step lesson plan.")
                }

                Section {
                    TextField("e.g. swift, swiftui, ios, algorithms", text: $searchTag)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Search tag (optional)")
                } footer: {
                    Text("Used to find dev.to articles and curated docs for this topic. Leave blank to guess one from the title.")
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addTopic() {
        let topic = Topic(
            title: title,
            topicDescription: description,
            orderIndex: subject.topics.count,
            searchTag: searchTag
        )
        topic.subject = subject
        modelContext.insert(topic)
        dismiss()
    }
}
