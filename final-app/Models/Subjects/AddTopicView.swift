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
                    TextField("Topic title (e.g. Big O Notation)", text: $title)
                    TextField("Short description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
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
