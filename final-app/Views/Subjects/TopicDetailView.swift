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
    @ObservedObject private var network = NetworkMonitor.shared
    @Bindable var topic: Topic
    @State private var showingAddResource = false
    @State private var phase: Phase = .idle
    @State private var discoveryError: String?
    @State private var discoverySummary: String?

    enum Phase: Equatable {
        case idle, searching, planning

        var message: String {
            switch self {
            case .idle: return ""
            case .searching: return "Finding relevant videos, articles & docs…"
            case .planning: return "Building your lesson plan…"
            }
        }
    }

    private var isBusy: Bool { phase != .idle }

    // SwiftData doesn't keep a relationship's order, so the list could jump around
    // when a resource changed (e.g. Mark complete). A fixed sort keeps rows in place.
    private var sortedResources: [LearningResource] {
        topic.resources.sorted { ($0.addedAt, $0.title) < ($1.addedAt, $1.title) }
    }
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
                TextField(
                    "e.g. Assignment 2: model a one-to-many relationship in SwiftData and query it with #Predicate",
                    text: $topic.topicDescription,
                    axis: .vertical
                )
                .lineLimit(3...8)
            } header: {
                Text("What do you need to learn?")
            } footer: {
                Text("Be specific: concepts, the assignment, the tools. This description is used to find more relevant resources and to shape your lesson plan.")
            }

            lessonPlanSection

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
                        if isBusy {
                            ProgressView().padding(.trailing, 4)
                            Text(phase.message)
                        } else {
                            Label(
                                topic.hasSearchedForResources ? "Search Again" : "Find Resources",
                                systemImage: "sparkle.magnifyingglass"
                            )
                        }
                    }
                }
                .disabled(isBusy || !network.isConnected)

                if !network.isConnected {
                    Label("You're offline. Your saved resources and lesson plan still work; finding new resources needs the internet.", systemImage: "wifi.slash")
                        .font(.sgCaption)
                        .foregroundStyle(.orange)
                }

                if let discoverySummary {
                    Text(discoverySummary)
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }

                if topic.hasSearchedForResources {
                    Text("Already searched once: this will call the YouTube API again (costs quota). Use it after changing the description or search tag.")
                        .font(.sgCaption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("Searches once using the title and description above, caches the results and builds a lesson plan. It won't re-query automatically.")
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
                ForEach(sortedResources) { resource in
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

    // MARK: - Lesson plan

    @ViewBuilder
    private var lessonPlanSection: some View {
        Section {
            if let plan = topic.lessonPlan {
                NavigationLink {
                    LessonPlanView(topic: topic)
                } label: {
                    lessonPlanSummary(plan)
                }
            } else {
                Button(action: buildLessonPlan) {
                    Label("Build Lesson Plan", systemImage: "list.number")
                }
                .disabled(isBusy || topic.resources.isEmpty)
            }
        } header: {
            Text("Lesson Plan")
        } footer: {
            if topic.lessonPlan == nil {
                Text(topic.resources.isEmpty
                     ? "Find resources first, then they'll be arranged into step-by-step lessons."
                     : "Arranges these resources into clear steps, with practice tasks and checkpoints.")
            }
        }
    }

    private func lessonPlanSummary(_ plan: LessonPlan) -> some View {
        let completed = plan.steps.filter { topic.isStepCompleted($0) }.count

        return VStack(alignment: .leading, spacing: 6) {
            Label(
                plan.source == .gemini ? "AI lesson plan" : "Lesson plan",
                systemImage: plan.source == .gemini ? "sparkles" : "list.number"
            )
            .font(.spaceGrotesk(size: 15, weight: .bold))

            Text("\(completed)/\(plan.steps.count) steps · \(plan.totalMinutes) min")
                .font(.sgCaption)
                .foregroundStyle(.secondary)

            if let next = topic.nextLessonStep {
                Text("Up next: \(next.title)")
                    .font(.sgCaption)
                    .foregroundStyle(.red)
            } else {
                Text("All steps complete")
                    .font(.sgCaption)
                    .foregroundStyle(.green)
            }

            ProgressView(value: Double(completed), total: Double(max(plan.steps.count, 1)))
                .tint(.red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    // Finds resources using the description, then builds a lesson plan from them.
    private func runDiscovery() {
        phase = .searching
        discoveryError = nil
        discoverySummary = nil
        Task {
            let outcome = await ResourceDiscoveryService.discoverResources(for: topic, modelContext: modelContext)
            var messages = outcome.failureMessages

            if let plan = outcome.searchPlan {
                var summary = "Added \(outcome.addedCount) resources"
                if outcome.filteredOutCount > 0 {
                    summary += " (\(outcome.filteredOutCount) skipped as not relevant)"
                }
                summary += ". \(plan.usedAI ? "AI-planned" : "Keyword") search: “\(plan.youtubeQuery)”"
                discoverySummary = summary
            }

            if !topic.resources.isEmpty {
                phase = .planning
                let result = await LessonPlanService.generatePlan(for: topic)
                topic.lessonPlan = result.plan
                if let warning = result.warning { messages.append(warning) }
            }

            discoveryError = messages.isEmpty ? nil : messages.joined(separator: "\n")
            phase = .idle
        }
    }

    private func buildLessonPlan() {
        phase = .planning
        discoveryError = nil
        Task {
            let result = await LessonPlanService.generatePlan(for: topic)
            topic.lessonPlan = result.plan
            discoveryError = result.warning
            phase = .idle
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
                        topic.toggleCompletion(of: resource, modelContext: modelContext)
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
