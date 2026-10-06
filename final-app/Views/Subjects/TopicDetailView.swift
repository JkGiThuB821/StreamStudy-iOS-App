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
                    AdaptiveStack(verticalAlignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(completedResourceCount) / \(topic.resources.count)")
                                .font(.spaceGrotesk(size: 28, weight: .bold))

                            Text("resources completed")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

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
                    AdaptiveStack(spacing: 8) {
                        Text("Search tag")
                        Spacer(minLength: 0)
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
    
    // Completing a resource records its duration as study time, which feeds the
    // "Study Activity" chart and "This week" total on the Progress tab.
    // Un-completing it removes today's matching entry so time isn't double counted.
    private func logStudyTime(for resource: LearningResource) {
        if resource.isCompleted {
            let entry = StudyProgress(minutesSpent: resource.durationMinutes)
            entry.topic = topic
            modelContext.insert(entry)
        } else if let entry = topic.progressEntries
            .filter({ Calendar.current.isDateInToday($0.date) && $0.minutesSpent == resource.durationMinutes })
            .max(by: { $0.date < $1.date }) {
            modelContext.delete(entry)
        }
    }

    private var completedResourceCount: Int {
        topic.resources.filter(\.isCompleted).count
    }
    
    private func resourceRow(_ resource: LearningResource) -> some View {
        HStack(alignment: .top, spacing: 12) {

            // MARK: Resource icon
            Image(systemName: resource.type.sfSymbol)
                .font(.headline)
                .foregroundStyle(
                    resource.isCompleted ? Color.secondary : .red
                )

            // Info and the complete button sit side by side, or stack at large text sizes.
            AdaptiveStack(spacing: 8) {
                // MARK: Resource information
                Button {
                    guard let url = URL(string: resource.urlString) else {
                        return
                    }

                    UIApplication.shared.open(url)
                } label: {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // MARK: Completion action
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resource.isCompleted.toggle()
                        logStudyTime(for: resource)

                        // A topic becomes complete when all its resources
                        // have been completed.
                        if !topic.resources.isEmpty {
                            topic.isCompleted = topic.resources.allSatisfy(\.isCompleted)
                        }
                    }
                } label: {
                    Text(resource.isCompleted ? "Completed" : "Mark complete")
                        .font(.sgCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            resource.isCompleted ? .secondary : Color.red
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}
