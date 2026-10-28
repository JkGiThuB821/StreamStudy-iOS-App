//
//  OnboardingView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 14/10/2026.
//

import SwiftUI
import SwiftData

// Shown once per account after signing in: collects a display name, starter
// subjects and study preferences, then hands over to the main app.
struct OnboardingView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncService: FirestoreSyncService
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var network = NetworkMonitor.shared
    @Query private var existingSubjects: [Subject]

    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(UserPreferences.onboardedUserIDsKey) private var onboardedUserIDs = ""
    @AppStorage(UserPreferences.replayOnboardingKey) private var replayOnboarding = false
    @AppStorage(NotificationService.remindersEnabledKey) private var remindersEnabled = true

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var selectedSubjects: Set<String> = []
    @State private var customSubjects: [SuggestedSubject] = []
    @State private var customSubjectDraft = ""
    @State private var isFinishing = false

    @ScaledMetric(relativeTo: .title) private var heroIconSize: CGFloat = 64

    enum Step: Int, CaseIterable {
        case welcome, name, subjects, preferences
    }

    private var allSuggestions: [SuggestedSubject] {
        SuggestedSubject.defaults + customSubjects
    }

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case .welcome: welcomeStep
                    case .name: nameStep
                    case .subjects: subjectsStep
                    case .preferences: preferencesStep
                    }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            navigationButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
        .onAppear {
            if name.isEmpty { name = authManager.displayName ?? "" }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: heroIconSize))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Text("Welcome to StreamStudy")
                .font(.sgTitle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Let's set things up in under a minute: your name, your subjects and how you like to study.")
                .font(.sgBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What should we call you?", detail: "Shown on your Home screen and profile.")

            TextField("Display name", text: $name)
                .characterLimit($name, TextLimits.name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var subjectsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(
                "Which subjects are you studying?",
                detail: "Pick a few to start with. You can add, rename or delete subjects any time."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(allSuggestions) { suggestion in
                    subjectChip(suggestion)
                }
            }

            HStack {
                TextField("Add your own subject", text: $customSubjectDraft)
                    .characterLimit($customSubjectDraft, TextLimits.name)
                    .textInputAutocapitalization(.words)
                    .onSubmit(addCustomSubject)
                Button("Add", action: addCustomSubject)
                    .disabled(customSubjectDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHeader("How do you like to study?", detail: "You can change these later in Account.")

            VStack(alignment: .leading, spacing: 8) {
                Text("APPEARANCE").font(.sgCaption).foregroundStyle(.secondary)
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Remind me before deadlines", isOn: $remindersEnabled)
                .tint(.red)
        }
    }

    // MARK: - Pieces

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.red : Color.cardStroke)
                    .frame(width: item == step ? 24 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private func stepHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.sgTitle2)
            Text(detail).font(.sgSubheadline).foregroundStyle(.secondary)
        }
    }

    private func subjectChip(_ suggestion: SuggestedSubject) -> some View {
        let isSelected = selectedSubjects.contains(suggestion.name)

        return Button {
            if isSelected {
                selectedSubjects.remove(suggestion.name)
            } else {
                selectedSubjects.insert(suggestion.name)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: suggestion.iconName)
                    .foregroundStyle(Color(hex: suggestion.colorHex))
                    .frame(minWidth: 22)
                Text(suggestion.name)
                    .font(.spaceGrotesk(size: 14, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.red : Color.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.red.opacity(0.12) : Color.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : Color.cardStroke, lineWidth: isSelected ? 1.5 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var navigationButtons: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if step == .preferences {
                Button(action: finish) {
                    if isFinishing || syncService.isSyncing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Get Started")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                // Wait for the sign-in sync to finish so it can't overwrite new subjects.
                .disabled(isFinishing || syncService.isSyncing)
            } else {
                Button(step == .welcome ? "Let's Go" : "Next") {
                    if let next = Step(rawValue: step.rawValue + 1) { step = next }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(step == .name && name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .font(.spaceGrotesk(size: 16, weight: .semibold))
    }

    // MARK: - Actions

    private func addCustomSubject() {
        let trimmed = customSubjectDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !allSuggestions.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }

        let colors = SuggestedSubject.defaults.map(\.colorHex)
        customSubjects.append(SuggestedSubject(
            name: trimmed,
            description: "",
            iconName: "book.closed.fill",
            colorHex: colors[customSubjects.count % colors.count]
        ))
        selectedSubjects.insert(trimmed)
        customSubjectDraft = ""
    }

    private func finish() {
        guard let uid = authManager.uid else { return }
        isFinishing = true

        // Add the chosen subjects, skipping any the account already has.
        let existingNames = Set(existingSubjects.map { $0.name.lowercased() })
        let toAdd = allSuggestions.filter {
            selectedSubjects.contains($0.name) && !existingNames.contains($0.name.lowercased())
        }
        for suggestion in toAdd {
            modelContext.insert(Subject(
                name: suggestion.name,
                subjectDescription: suggestion.description,
                colorHex: suggestion.colorHex,
                iconName: suggestion.iconName
            ))
        }
        try? modelContext.save()

        Task {
            await authManager.updateDisplayName(name)
            if network.isConnected {
                await syncService.push(uid: uid, modelContext: modelContext)
            }
            // Saved to the account too, so it isn't repeated on another device.
            syncService.markOnboardingComplete(uid: uid)
            onboardedUserIDs = UserPreferences.adding(uid, to: onboardedUserIDs)
            replayOnboarding = false
            isFinishing = false
        }
    }
}

// MARK: - Suggested subjects

struct SuggestedSubject: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let iconName: String
    let colorHex: String

    static let defaults: [SuggestedSubject] = [
        SuggestedSubject(name: "iOS Development", description: "Swift, SwiftUI and building apps", iconName: "iphone", colorHex: "#E50914"),
        SuggestedSubject(name: "Algorithms & Data Structures", description: "Big O, sorting, trees and graphs", iconName: "cpu", colorHex: "#3498DB"),
        SuggestedSubject(name: "Databases", description: "SQL, data modelling and queries", iconName: "cylinder.split.1x2", colorHex: "#2ECC71"),
        SuggestedSubject(name: "Web Development", description: "HTML, CSS, JavaScript and the web", iconName: "globe", colorHex: "#F39C12"),
        SuggestedSubject(name: "Software Engineering", description: "Design, testing and teamwork", iconName: "chevron.left.forwardslash.chevron.right", colorHex: "#9B59B6"),
        SuggestedSubject(name: "Machine Learning", description: "Models, training data and evaluation", iconName: "brain.head.profile", colorHex: "#E91E8C"),
        SuggestedSubject(name: "Cybersecurity", description: "Threats, encryption and secure code", iconName: "lock.fill", colorHex: "#3498DB"),
    ]
}
