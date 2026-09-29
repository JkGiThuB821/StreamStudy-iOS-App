//
//  TopicDetailView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct TopicDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var topic: Topic
    @State private var showingAddResource = false
    @State private var isDiscovering = false
    @State private var discoveryError: String?

    var body: some View {
        List {
            Section {
                Toggle("Mark topic complete", isOn: $topic.isCompleted)
                    .tint(.red)
            }

            if !topic.hasSearchedForResources {
                Section {
                    Button(action: runDiscovery) {
                        HStack {
                            if isDiscovering {
                                ProgressView().padding(.trailing, 4)
                                Text("Searching YouTube, dev.to & docs…")
                            } else {
                                Label("Find Resources", systemImage: "sparkle.magnifyingglass")
                            }
                        }
                    }
                    .disabled(isDiscovering)

                    Text("Searches once for “\(ResourceDiscoveryService.tag(for: topic))” and caches results — this won't re-query automatically.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let discoveryError {
                        Text(discoveryError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Episodes") {
                ForEach(topic.resources) { resource in
                    resourceRow(resource)
                }

                if topic.resources.isEmpty {
                    Text(topic.hasSearchedForResources
                         ? "No resources found — try adding one manually."
                         : "No resources yet — tap Find Resources or + to add one.")
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

    private func runDiscovery() {
        isDiscovering = true
        discoveryError = nil
        Task {
            let outcome = await ResourceDiscoveryService.discoverResources(for: topic, modelContext: modelContext)
            if outcome.hasPartialFailure {
                discoveryError = outcome.failureMessages.joined(separator: "\n")
            }
            isDiscovering = false
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
