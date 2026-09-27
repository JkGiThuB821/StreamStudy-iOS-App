//
//  TopicDetailView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct TopicDetailView: View {
    @Bindable var topic: Topic
    @State private var showingAddResource = false

    var body: some View {
        List {
            Section {
                Toggle("Mark topic complete", isOn: $topic.isCompleted)
                    .tint(.red)
            }

            Section("Episodes") {
                ForEach(topic.resources) { resource in
                    resourceRow(resource)
                }

                if topic.resources.isEmpty {
                    Text("No resources yet — tap + to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(topic.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddResource = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddResource) {
            AddResourceView(topic: topic)
        }
    }

    private func resourceRow(_ resource: LearningResource) -> some View {
        HStack {
            Image(systemName: resource.type.sfSymbol)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title).font(.subheadline.bold())
                Text("\(resource.sourceName) · \(resource.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                resource.isCompleted.toggle()
            } label: {
                Image(systemName: resource.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(resource.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
