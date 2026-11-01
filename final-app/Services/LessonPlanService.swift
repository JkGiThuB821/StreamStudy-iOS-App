//
//  LessonPlanService.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 6/10/2026.
//

import Foundation

// Turns a topic's videos, articles and docs into an ordered, step-by-step
// lesson plan. Gemini designs the plan as JSON when a key is configured;
// otherwise (or if the call fails) a rule-based plan is built on-device.
@MainActor
enum LessonPlanService {

    static func generatePlan(for topic: Topic) async -> (plan: LessonPlan, warning: String?) {
        let resources = orderedResources(for: topic)

        guard GeminiService.isAvailable, !resources.isEmpty else {
            return (localPlan(for: topic, resources: resources), nil)
        }

        do {
            let ai = try await GeminiService.generateJSON(
                AILessonPlan.self,
                prompt: prompt(for: topic, resources: resources),
                schema: schema
            )
            let plan = convert(ai, resources: resources)
            guard !plan.steps.isEmpty else { throw GeminiServiceError.emptyResponse }
            return (plan, nil)
        } catch {
            return (
                localPlan(for: topic, resources: resources),
                "AI lesson plan unavailable, built a standard plan instead. (\(error.localizedDescription))"
            )
        }
    }

    // MARK: - Gemini

    // Internal (not private) so unit tests can check the validation in convert().
    struct AILessonPlan: Decodable {
        let summary: String
        let steps: [Step]

        struct Step: Decodable {
            let title: String
            let objective: String
            let kind: String
            let resourceIndexes: [Int]
            let estimatedMinutes: Int
            let activity: String
            let checkpointQuestion: String
        }
    }

    private static func prompt(for topic: Topic, resources: [LearningResource]) -> String {
        // Resources are referred to by index so the model can't invent IDs or URLs.
        let list = resources.enumerated().map { index, resource -> String in
            let description = resource.resourceDescription
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(250)
            return "[\(index)] \(resource.type.displayName.uppercased()) · \(resource.durationMinutes) min · \(resource.sourceName) · \"\(resource.title)\" — \(description)"
        }
        .joined(separator: "\n")

        return """
        You are a university tutor designing a short, step-by-step lesson plan.

        Subject: \(topic.subject?.name ?? "Unknown")
        Topic: \(topic.title)
        What the student needs to learn or do: \(topic.topicDescription.isEmpty ? "(no description given — cover the fundamentals of the topic)" : topic.topicDescription)
        Student's self-rating: \(difficultyText(topic.difficulty))

        Available resources (refer to them ONLY by their [index]):
        \(list)

        Build a plan of 3 to 6 steps that goes from fundamentals to applying the knowledge,
        focused on what the description asks for. Rules:
        - Mix reading (docs/articles) and videos so each step builds on the last.
        - kind is one of: read, watch, practice, review.
        - read/watch steps list 1 to 3 resourceIndexes; use each resource at most once and
          leave out resources that are not relevant to the description.
        - Include at least one practice step with no resources whose activity is a concrete,
          hands-on task tied to the description (e.g. the assignment the student mentions).
        - End with a review step (no resources) whose activity is a short self-test.
        - objective: one sentence saying what the student will be able to do after the step.
        - activity: concrete instructions for practice/review steps; for read/watch steps say
          what to focus on while studying the resources.
        - checkpointQuestion: one question the student should be able to answer after the step.
        - estimatedMinutes: realistic time for the step.
        - summary: one or two sentences describing the plan.
        """
    }

    private static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "summary": ["type": "STRING"],
            "steps": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "title": ["type": "STRING"],
                        "objective": ["type": "STRING"],
                        "kind": ["type": "STRING"], // read | watch | practice | review (validated in convert)
                        "resourceIndexes": ["type": "ARRAY", "items": ["type": "INTEGER"]],
                        "estimatedMinutes": ["type": "INTEGER"],
                        "activity": ["type": "STRING"],
                        "checkpointQuestion": ["type": "STRING"],
                    ],
                    "required": [
                        "title", "objective", "kind", "resourceIndexes",
                        "estimatedMinutes", "activity", "checkpointQuestion",
                    ],
                ],
            ],
        ],
        "required": ["summary", "steps"],
    ]

    // Validates the model's JSON: drops unknown/duplicate indexes and empty
    // steps, and recalculates times for steps that have resources.
    static func convert(_ ai: AILessonPlan, resources: [LearningResource]) -> LessonPlan {
        var used = Set<Int>()

        let steps: [LessonStep] = ai.steps.compactMap { step -> LessonStep? in
            let indexes = step.resourceIndexes.filter {
                resources.indices.contains($0) && used.insert($0).inserted
            }
            let stepResources = indexes.map { resources[$0] }
            var kind = LessonStep.Kind(rawValue: step.kind.lowercased()) ?? .practice

            // A read/watch step whose resources were all invalid becomes practice,
            // or is dropped if it has nothing to do either.
            if stepResources.isEmpty && (kind == .read || kind == .watch) {
                guard !step.activity.isEmpty else { return nil }
                kind = .practice
            }

            let minutes = stepResources.isEmpty
                ? min(max(step.estimatedMinutes, 5), 90)
                : stepResources.reduce(0) { $0 + $1.durationMinutes }

            return LessonStep(
                id: UUID(),
                title: step.title,
                objective: step.objective,
                kind: kind,
                estimatedMinutes: minutes,
                resourceIDs: stepResources.map(\.id),
                activity: step.activity,
                checkpointQuestion: step.checkpointQuestion,
                isManuallyCompleted: false
            )
        }

        return LessonPlan(summary: ai.summary, steps: steps, source: .gemini, generatedAt: .now)
    }

    // MARK: - Local (no AI) plan

    static func localPlan(for topic: Topic, resources: [LearningResource]) -> LessonPlan {
        let reading = resources.filter { $0.type != .video }
        let videos = resources.filter { $0.type == .video }
        let focus = topic.topicDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        var steps: [LessonStep] = []

        func addStep(
            _ title: String, _ objective: String, _ kind: LessonStep.Kind,
            _ stepResources: [LearningResource], activity: String, question: String, minutes: Int? = nil
        ) {
            steps.append(LessonStep(
                id: UUID(),
                title: title,
                objective: objective,
                kind: kind,
                estimatedMinutes: minutes ?? stepResources.reduce(0) { $0 + $1.durationMinutes },
                resourceIDs: stepResources.map(\.id),
                activity: activity,
                checkpointQuestion: question,
                isManuallyCompleted: false
            ))
        }

        if let first = reading.first {
            addStep(
                "Get the big picture",
                "Understand what \(topic.title) is and the key terms involved.",
                .read, [first],
                activity: "Skim the headings first, then note down any terms you haven't seen before.",
                question: "In one sentence, what problem does \(topic.title) solve?"
            )
        }

        if let video = videos.first {
            addStep(
                "Watch it explained",
                "See \(topic.title) explained and demonstrated step by step.",
                .watch, [video],
                activity: "Pause when a new idea is introduced and try to predict what comes next.",
                question: "What was the most important example shown, and why did it work?"
            )
        }

        let moreReading = Array(reading.dropFirst().prefix(2))
        if !moreReading.isEmpty {
            addStep(
                "Go deeper",
                "Fill in the details and edge cases of \(topic.title).",
                .read, moreReading,
                activity: focus.isEmpty
                    ? "Focus on code samples and try to explain each line."
                    : "Focus on the parts that relate to: \(focus)",
                question: "What is one common mistake to avoid with \(topic.title)?"
            )
        }

        let moreVideos = Array(videos.dropFirst().prefix(2))
        if !moreVideos.isEmpty {
            addStep(
                "See it in action",
                "Reinforce the concepts with a different explanation.",
                .watch, moreVideos,
                activity: "Compare this explanation with the first one: what did it add?",
                question: "How would you explain \(topic.title) to a classmate?"
            )
        }

        addStep(
            "Practice",
            "Apply \(topic.title) yourself.",
            .practice, [],
            activity: focus.isEmpty
                ? "Build a small example that uses \(topic.title) from scratch, without copying from the resources."
                : "Apply what you've learned to your task: \(focus)",
            question: "Could you do this again without looking at the resources?",
            minutes: 25
        )

        addStep(
            "Review",
            "Check you understand \(topic.title) well enough to move on.",
            .review, [],
            activity: "Without notes, write a short summary of the topic and answer each step's checkpoint question. Revisit any step you couldn't answer.",
            question: "What would you still need to look up?",
            minutes: 10
        )

        let summary = focus.isEmpty
            ? "A \(steps.count)-step plan that moves from the basics of \(topic.title) to practising it yourself."
            : "A \(steps.count)-step plan focused on: \(focus)"

        return LessonPlan(summary: summary, steps: steps, source: .local, generatedAt: .now)
    }

    // MARK: - Helpers

    // Documentation first (most authoritative), then shorter resources first.
    private static func orderedResources(for topic: Topic) -> [LearningResource] {
        topic.resources.sorted { lhs, rhs in
            if (lhs.type == .documentation) != (rhs.type == .documentation) {
                return lhs.type == .documentation
            }
            return lhs.durationMinutes < rhs.durationMinutes
        }
    }

    private static func difficultyText(_ rating: DifficultyRating) -> String {
        switch rating {
        case .understood: return "already understands the basics"
        case .needsRevision: return "finds this topic difficult and needs revision"
        case .notRated: return "not rated yet"
        }
    }
}
