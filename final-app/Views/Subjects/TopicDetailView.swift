//
//  TopicDetailView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

// "Episode Detail" in the UI design proposal (mock-up 11): the topic's
// header, its lesson plan, then its resources grouped into WATCH and READ,
// each with a "Needs Revision | Understood" bar. Finding more resources
// sits underneath (Week 11 feedback: episodes above fetching).
struct TopicDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var network = NetworkMonitor.shared
    @Bindable var topic: Topic
    @State private var showingAddResource = false
    @State private var phase: Phase = .idle
    @State private var discoveryError: String?
    @State private var discoverySummary: String?
    @State private var isEditingTag = false
    @State private var tagDraft = ""

    @ScaledMetric(relativeTo: .body) private var thumbnailWidth: CGFloat = 72

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

    private var videos: [LearningResource] { sortedResources.filter { $0.type == .video } }
    private var reading: [LearningResource] { sortedResources.filter { $0.type != .video } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                lessonPlanCard

                if !videos.isEmpty {
                    resourceSection("Watch", resources: videos)
                }
                if !reading.isEmpty {
                    resourceSection("Read", resources: reading)
                }
                if topic.resources.isEmpty {
                    Text(topic.hasSearchedForResources
                         ? "No resources found: try a different search tag, or add one with +."
                         : "No resources yet: tap Find Resources below, or + to add one.")
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .cardStyle()
                }

                findResourcesCard
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .tabBarClearance()
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddResource = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add resource")
            }
        }
        .sheet(isPresented: $showingAddResource) {
            AddResourceView(topic: topic)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subject = topic.subject {
                Label(subject.name, systemImage: subject.iconName)
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: subject.colorHex), in: RoundedRectangle(cornerRadius: 6))
            }

            Text(topic.title)
                .font(.spaceGrotesk(size: 28, weight: .bold, relativeTo: .title))
                .fixedSize(horizontal: false, vertical: true)

            if !topic.topicDescription.isEmpty {
                Text(topic.topicDescription)
                    .font(.sgSubheadline)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { metaItems }
                VStack(alignment: .leading, spacing: 4) { metaItems }
            }
            .font(.sgCaption)

            ProgressView(value: topic.progress)
                .tint(topic.isCompleted ? .green : .red)
                .accessibilityLabel("Topic progress")
                .accessibilityValue("\(Int(topic.progress * 100)) percent")
        }
    }

    @ViewBuilder
    private var metaItems: some View {
        Label("\(topic.totalDurationMinutes) min", systemImage: "clock")
            .foregroundStyle(.secondary)
        Text("\(topic.resources.count) resource\(topic.resources.count == 1 ? "" : "s")")
            .foregroundStyle(.secondary)
        if topic.isCompleted {
            Label("Complete", systemImage: "circle.fill").foregroundStyle(.green)
        } else if topic.progress > 0 {
            Label("In Progress", systemImage: "circle.lefthalf.filled").foregroundStyle(.orange)
        } else {
            Label("Not Started", systemImage: "circle").foregroundStyle(.secondary)
        }
    }

    // MARK: - Lesson plan

    @ViewBuilder
    private var lessonPlanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(
                "Lesson Plan",
                info: "Arranges this topic's resources into clear steps (read, watch, practice, review) with checkpoints. Find resources first, then build the plan."
            )

            if let plan = topic.lessonPlan {
                NavigationLink {
                    LessonPlanView(topic: topic)
                } label: {
                    HStack {
                        lessonPlanSummary(plan)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            } else {
                Button(action: buildLessonPlan) {
                    Label("Build Lesson Plan", systemImage: "list.number")
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(isBusy || topic.resources.isEmpty)
                .opacity(topic.resources.isEmpty ? 0.5 : 1)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Resources (WATCH / READ)

    private func resourceSection(_ title: String, resources: [LearningResource]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title, info: nil)
            ForEach(resources) { resource in
                resourceCard(resource)
            }
        }
    }

    // A resource card with the proposal's "Needs Revision | Understood" bar.
    // The card can also be swiped (Swipe-to-Revise), and every rating feeds
    // the Season Pass signal pipeline for this topic.
    private func resourceCard(_ resource: LearningResource) -> some View {
        SwipeToReviseCard(currentRating: SignalPipeline.latestRating(for: resource), onRate: { rating in
            SignalPipeline.recordRating(rating, for: topic, resource: resource, source: .episode, in: modelContext)
        }, compact: true) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink {
                    ResourceDetailView(resource: resource)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ResourceThumbnail(resource: resource)
                            .frame(width: thumbnailWidth, height: thumbnailWidth * 0.66)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(resource.title)
                                .font(.spaceGrotesk(size: 15, weight: .bold))
                                .foregroundStyle(resource.isCompleted ? Color.secondary : Color.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                            HStack(spacing: 8) {
                                BadgeLabel(text: resource.sourceBadge.text, color: resource.sourceBadge.color, filled: false)
                                Label("\(resource.durationMinutes) min", systemImage: "clock")
                                    .font(.sgCaption)
                                    .foregroundStyle(.secondary)
                            }
                            if resource.isCompleted {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                                    .font(.spaceGrotesk(size: 12, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(spacing: 14) {
                    Button {
                        resource.isSaved.toggle()
                    } label: {
                        Image(systemName: resource.isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(resource.isSaved ? Color.red : Color.secondary)
                            .expandedTapArea(by: 10)
                    }
                    .accessibilityLabel("Save for later")
                    .accessibilityValue(resource.isSaved ? "Saved" : "Not saved")
                    .accessibilityHint(resource.isSaved ? "Removes this resource from your saved list" : "Adds this resource to your saved list")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            topic.toggleCompletion(of: resource, modelContext: modelContext)
                        }
                    } label: {
                        Image(systemName: resource.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(resource.isCompleted ? Color.green : Color.secondary)
                            .expandedTapArea(by: 10)
                    }
                    .accessibilityLabel("Complete")
                    .accessibilityValue(resource.isCompleted ? "Done" : "Not done")
                    .accessibilityHint("Updates this topic's progress")
                }
                .buttonStyle(.plain)
                .font(.title3)
            }
        }
    }

    // MARK: - Find more resources

    private var findResourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(
                "Find resources",
                info: "Searches YouTube, dev.to and curated docs once using the title, description and search tag, caches the results and builds a lesson plan. It won't re-query automatically: Search Again uses YouTube quota, so use it after changing the description or tag. dev.to and curated docs need the tag to match exactly; YouTube doesn't."
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("What do you need to learn?")
                        .font(.spaceGrotesk(size: 14, weight: .semibold))
                    InfoButton(
                        title: "What do you need to learn?",
                        message: "Be specific: concepts, the assignment, the tools. This description is used to find more relevant resources and to shape your lesson plan."
                    )
                }

                TextField(
                    "e.g. Assignment 2: model a one-to-many relationship in SwiftData and query it with #Predicate",
                    text: $topic.topicDescription,
                    axis: .vertical
                )
                .lineLimit(3...8)
                .characterLimit($topic.topicDescription, TextLimits.longDescription)
                .inputFieldStyle()

                if isEditingTag {
                    TextField("e.g. swift, swiftui, ios, combine, coredata", text: $tagDraft)
                        .textInputAutocapitalization(.never)
                        .characterLimit($tagDraft, TextLimits.tag)
                        .inputFieldStyle()
                    HStack {
                        Button("Save Tag") {
                            topic.searchTag = tagDraft.trimmingCharacters(in: .whitespaces)
                            isEditingTag = false
                        }
                        Spacer()
                        Button("Cancel", role: .cancel) { isEditingTag = false }
                    }
                    .font(.spaceGrotesk(size: 14, weight: .semibold))
                } else {
                    AdaptiveStack(spacing: 8) {
                        Text("Search tag")
                            .font(.spaceGrotesk(size: 14, weight: .semibold))
                        Spacer(minLength: 0)
                        Text(ResourceDiscoveryService.tag(for: topic))
                            .font(.sgCaption)
                            .foregroundStyle(.secondary)
                        Button("Edit") {
                            tagDraft = topic.searchTag
                            isEditingTag = true
                        }
                        .font(.sgCaption)
                    }
                }

                Button(action: runDiscovery) {
                    if isBusy {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text(phase.message)
                        }
                    } else {
                        Label(
                            topic.hasSearchedForResources ? "Search Again" : "Find Resources",
                            systemImage: "sparkle.magnifyingglass"
                        )
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isBusy || !network.isConnected)

                if !network.isConnected {
                    Label("You're offline. Finding new resources needs the internet.", systemImage: "wifi.slash")
                        .font(.sgCaption)
                        .foregroundStyle(.orange)
                }

                if let discoverySummary {
                    Text(discoverySummary)
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }

                if let discoveryError {
                    Text(discoveryError)
                        .font(.sgCaption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)
            .cardStyle()
        }
    }

    // "WATCH", "READ", "LESSON PLAN": small uppercase labels, as in the mock-up.
    private func sectionLabel(_ title: String, info: String?) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            if let info {
                InfoButton(title: title, message: info)
            }
        }
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

            // AI-assisted tagging runs afterwards in the background; nothing waits on it.
            await ResourceTaggingService.tagUntaggedResources(in: topic)
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
}
