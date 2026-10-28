//
//  LessonPlanView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import SwiftUI
import SwiftData

struct LessonPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var topic: Topic

    @State private var isRegenerating = false
    @State private var regenerateWarning: String?
    @State private var showingRegenerateConfirm = false
    @State private var revealedCheckpoints: Set<UUID> = []

    @ScaledMetric(relativeTo: .headline) private var stepBadgeSize: CGFloat = 30

    var body: some View {
        ScrollView {
            if let plan = topic.lessonPlan {
                VStack(alignment: .leading, spacing: 18) {
                    header(plan)

                    if let regenerateWarning {
                        Text(regenerateWarning)
                            .font(.sgCaption)
                            .foregroundStyle(.orange)
                    }

                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                        stepCard(step, number: index + 1, isNext: step.id == topic.nextLessonStep?.id)
                    }

                    extraResources(plan)
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "No lesson plan yet",
                    systemImage: "list.number",
                    description: Text("Find resources for this topic, then build a lesson plan.")
                )
                .padding(.top, 60)
            }
        }
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle("Lesson Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isRegenerating {
                    ProgressView()
                } else {
                    Button {
                        showingRegenerateConfirm = true
                    } label: {
                        Label("Rebuild Plan", systemImage: "arrow.clockwise")
                    }
                    .disabled(topic.resources.isEmpty)
                }
            }
        }
        .confirmationDialog(
            "Rebuild this lesson plan?",
            isPresented: $showingRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Rebuild Plan") { regenerate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your completed resources are kept, but ticked-off practice and review steps will reset.")
        }
    }

    // MARK: - Header

    private func header(_ plan: LessonPlan) -> some View {
        let completedSteps = plan.steps.filter { topic.isStepCompleted($0) }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text(topic.title)
                .font(.spaceGrotesk(size: 24, weight: .bold))

            Text(plan.summary)
                .font(.sgSubheadline)
                .foregroundStyle(.secondary)

            AdaptiveStack(spacing: 8) {
                badge(
                    plan.source == .gemini ? "Planned by Gemini" : "Standard plan",
                    systemImage: plan.source == .gemini ? "sparkles" : "list.bullet"
                )
                badge("\(plan.steps.count) steps", systemImage: "list.number")
                badge("\(plan.totalMinutes) min", systemImage: "clock")
            }

            ProgressView(value: Double(completedSteps), total: Double(max(plan.steps.count, 1)))
                .tint(.red)

            Text("\(completedSteps) of \(plan.steps.count) steps complete")
                .font(.sgCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.red.opacity(0.25), Color.cardFill],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.spaceGrotesk(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.cardFill)
            .clipShape(Capsule())
    }

    // MARK: - Step card

    private func stepCard(_ step: LessonStep, number: Int, isNext: Bool) -> some View {
        let isDone = topic.isStepCompleted(step)
        let stepResources = topic.stepResources(for: step)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Week 11 feedback: the step's tick is tappable and completes the whole step.
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleStep(step) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isDone ? Color.green : (isNext ? Color.red : Color.cardFill))
                        Circle()
                            .stroke(isDone ? Color.green : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(number)")
                                .font(.spaceGrotesk(size: 14, weight: .bold))
                                .foregroundStyle(isNext ? Color.white : Color.primary)
                        }
                    }
                    .frame(width: stepBadgeSize, height: stepBadgeSize)
                    .frame(minWidth: 44, minHeight: 44)   // comfortable tap target
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(number): \(step.title)")
                .accessibilityValue(isDone ? "Done" : "Not done")
                .accessibilityHint(isDone ? "Marks this step as not done" : "Marks this step as done")

                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveStack(spacing: 6) {
                        Label(step.kind.displayName, systemImage: step.kind.sfSymbol)
                            .font(.spaceGrotesk(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                        Text("Â· \(step.estimatedMinutes) min")
                            .font(.sgCaption2)
                            .foregroundStyle(.secondary)
                        if isNext {
                            Text("UP NEXT")
                                .font(.spaceGrotesk(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(step.title)
                        .font(.spaceGrotesk(size: 17, weight: .bold))
                        .strikethrough(isDone, color: .secondary)

                    Text(step.objective)
                        .font(.sgSubheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !step.activity.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stepResources.isEmpty ? "YOUR TASK" : "FOCUS ON")
                        .font(.spaceGrotesk(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(step.activity)
                        .font(.sgSubheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            ForEach(stepResources) { resource in
                resourceRow(resource)
            }

            if !step.checkpointQuestion.isEmpty {
                checkpoint(step)
            }

            if stepResources.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        topic.toggleManualCompletion(of: step)
                    }
                } label: {
                    Label(
                        isDone ? "Step done" : "Mark step done",
                        systemImage: isDone ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.spaceGrotesk(size: 14, weight: .bold))
                }
                .buttonStyle(.bordered)
                .tint(isDone ? .green : .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isNext ? Color.red.opacity(0.6) : Color.cardStroke, lineWidth: isNext ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isDone ? 0.75 : 1)
    }

    // Ticks a whole step on or off. Steps with resources complete (or reopen)
    // each of their resources, which also logs study time; steps without
    // resources use the manual flag.
    private func toggleStep(_ step: LessonStep) {
        let items = topic.stepResources(for: step)
        guard !items.isEmpty else {
            topic.toggleManualCompletion(of: step)
            return
        }

        let markDone = !topic.isStepCompleted(step)
        for resource in items where resource.isCompleted != markDone {
            topic.toggleCompletion(of: resource, modelContext: modelContext)
        }
    }

    private func checkpoint(_ step: LessonStep) -> some View {
        let isRevealed = revealedCheckpoints.contains(step.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isRevealed {
                    revealedCheckpoints.remove(step.id)
                } else {
                    revealedCheckpoints.insert(step.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label("Checkpoint", systemImage: "questionmark.bubble")
                    .font(.spaceGrotesk(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                if isRevealed {
                    Text(step.checkpointQuestion)
                        .font(.sgSubheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Tap to test yourself")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resources

    private func resourceRow(_ resource: LearningResource) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: resource.type.sfSymbol)
                .font(.headline)
                .foregroundStyle(resource.isCompleted ? Color.secondary : Color.red)

            AdaptiveStack(spacing: 8) {
                Button {
                    if let url = URL(string: resource.urlString) { openURL(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resource.title)
                            .font(.spaceGrotesk(size: 15, weight: .semibold))
                            .foregroundStyle(resource.isCompleted ? .secondary : .primary)
                            .strikethrough(resource.isCompleted, color: .secondary)
                            .multilineTextAlignment(.leading)
                        Text("\(resource.sourceName) Â· \(resource.durationMinutes) min")
                            .font(.sgCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        topic.toggleCompletion(of: resource, modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: resource.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(resource.isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(resource.isCompleted ? "Mark incomplete" : "Mark complete")
            }
        }
    }

    // Resources the plan left out (e.g. judged less relevant), still available.
    @ViewBuilder
    private func extraResources(_ plan: LessonPlan) -> some View {
        let planned = Set(plan.steps.flatMap(\.resourceIDs))
        let extras = topic.resources
            .filter { !planned.contains($0.id) }
            .sorted { ($0.addedAt, $0.title) < ($1.addedAt, $1.title) }   // stable order

        if !extras.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(extras) { resource in
                        resourceRow(resource)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Extra resources (\(extras.count))")
                    .font(.sgHeadline)
            }
            .tint(.primary)
            .padding()
            .background(Color.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func regenerate() {
        isRegenerating = true
        regenerateWarning = nil
        Task {
            let result = await LessonPlanService.generatePlan(for: topic)
            topic.lessonPlan = result.plan
            regenerateWarning = result.warning
            revealedCheckpoints = []
            isRegenerating = false
        }
    }
}
