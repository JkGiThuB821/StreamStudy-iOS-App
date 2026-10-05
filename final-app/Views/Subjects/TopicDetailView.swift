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
    @State private var isEditingTag = false
    @State private var tagDraft = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(completedResourceCount) / \(topic.resources.count)")
                                .font(.spaceGrotesk(size: 28, weight: .bold))

                            Text("resources completed")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(Int(topic.progress * 100))%")
                            .font(.spaceGrotesk(size: 28, weight: .bold))
                            .foregroundStyle(topic.isCompleted ? .green : .red)
                    }

                    ProgressView(value: topic.progress)
                        .tint(topic.isCompleted ? .green : .red)

                    HStack(spacing: 6) {
                        Image(
                            systemName: topic.isCompleted
                                ? "checkmark.circle.fill"
                                : "circle"
                        )

                        Text(
                            topic.isCompleted
                                ? "Topic completed"
                                : "Topic in progress"
                        )
                        .font(.sgCaption)
                        .fontWeight(.semibold)
                    }
                    .foregroundStyle(topic.isCompleted ? .green : .secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                Picker("How well do you know this?", selection: $topic.difficulty) {
                    Text("Not rated").tag(DifficultyRating.notRated)
                    Text("Understood").tag(DifficultyRating.understood)
                    Text("Needs revision").tag(DifficultyRating.needsRevision)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Feeds the \"what should I study next\" recommendation on Home.")
            }

            Section {
                if isEditingTag {
                    TextField("e.g. swift, swiftui, ios, combine, coredata", text: $tagDraft)
                        .textInputAutocapitalization(.never)
                    HStack {
                        Button("Save Tag") {
                            topic.searchTag = tagDraft
                            isEditingTag = false
                        }
                        Spacer()
                        Button("Cancel", role: .cancel) { isEditingTag = false }
                    }
                } else {
                    HStack {
                        Text("Search tag")
                        Spacer()
                        Text(ResourceDiscoveryService.tag(for: topic))
                            .foregroundStyle(.secondary)
                        Button("Edit") {
                            tagDraft = topic.searchTag
                            isEditingTag = true
                        }
                        .font(.sgCaption)
                    }
                }
            } footer: {
                Text("dev.to articles and curated docs need this tag to match exactly and YouTube search doesn't, which is why YouTube can return results even when the other two don't.")
            }

            Section {
                Button(action: runDiscovery) {
                    HStack {
                        if isDiscovering {
                            ProgressView().padding(.trailing, 4)
                            Text("Searching YouTube, dev.to & docs…")
                        } else {
                            Label(
                                topic.hasSearchedForResources ? "Search Again" : "Find Resources",
                                systemImage: "sparkle.magnifyingglass"
                            )
                        }
                    }
                }
                .disabled(isDiscovering)

                if topic.hasSearchedForResources {
                    Text("Already searched once: this will call the YouTube API again (costs quota). Use it after changing the search tag above.")
                        .font(.sgCaption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("Searches once for “\(ResourceDiscoveryService.tag(for: topic))” and caches results — this won't re-query automatically.")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }

                if let discoveryError {
                    Text(discoveryError)
                        .font(.sgCaption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Episodes") {
                ForEach(topic.resources) { resource in
                    resourceRow(resource)
                }

                if topic.resources.isEmpty {
                    Text(topic.hasSearchedForResources
                         ? "No resources found: try a different search tag, or add one manually."
                         : "No resources yet: tap Find Resources or + to add one.")
                        .font(.sgCaption)
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
        .onAppear {
            print("TOPIC ID:", topic.id.uuidString)
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

//    private func resourceRow(_ resource: LearningResource) -> some View {
//        HStack {
//            Image(systemName: resource.type.sfSymbol)
//                .foregroundStyle(.red)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(resource.title).font(.spaceGrotesk(size: 15, weight: .bold))
//                Text("\(resource.sourceName) · \(resource.durationMinutes) min")
//                    .font(.sgCaption)
//                    .foregroundStyle(.secondary)
//            }
//            Spacer()
//            Button {
//                resource.isCompleted.toggle()
//            } label: {
//                Image(systemName: resource.isCompleted ? "checkmark.circle.fill" : "circle")
//                    .foregroundStyle(resource.isCompleted ? .green : .secondary)
//            }
//            .buttonStyle(.plain)
//        }
//    }
    
    private var completedResourceCount: Int {
        topic.resources.filter(\.isCompleted).count
    }
    
    private func resourceRow(_ resource: LearningResource) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                resource.isCompleted.toggle()

                if !topic.resources.isEmpty {
                    topic.isCompleted = topic.resources.allSatisfy(\.isCompleted)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: resource.type.sfSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        resource.isCompleted ? Color.secondary : .red
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.title)
                        .font(.spaceGrotesk(size: 15, weight: .bold))
                        .foregroundStyle(
                            resource.isCompleted ? .secondary : .primary
                        )
                        .strikethrough(
                            resource.isCompleted,
                            color: .secondary
                        )

                    Text("\(resource.sourceName) · \(resource.durationMinutes) min")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if resource.isCompleted {
                    Text("Completed")
                        .font(.sgCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
