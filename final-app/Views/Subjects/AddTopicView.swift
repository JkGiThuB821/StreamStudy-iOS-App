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

    var body: some View {
        NavigationStack {
            Form {
                Section("New Topic") {
                    TextField("Topic title (e.g. Big O Notation)", text: $title)
                    TextField("Short description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
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
            orderIndex: subject.topics.count
        )
        topic.subject = subject
        modelContext.insert(topic)
        dismiss()
    }
}

