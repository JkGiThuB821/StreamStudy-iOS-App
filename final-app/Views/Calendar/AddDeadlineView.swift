//
//  AddDeadlineView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026

import SwiftUI
import SwiftData

struct AddDeadlineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var subject: Subject?

    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var selectedSubject: Subject?
    @State private var title = ""
    @State private var dueDate = Date.now.addingTimeInterval(60 * 60 * 24 * 7)
    @State private var priority: DeadlinePriority = .medium

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Add Deadline")
                        .font(.spaceGrotesk(size: 22, weight: .bold, relativeTo: .title2))
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.spaceGrotesk(size: 15, weight: .semibold))
                }

                TextField("Title (e.g. Mid-semester exam)", text: $title)
                    .characterLimit($title, TextLimits.title)
                    .inputFieldStyle()

                if subject == nil {
                    Menu {
                        Picker("Subject", selection: $selectedSubject) {
                            Text("None").tag(Subject?.none)
                            ForEach(subjects) { Text($0.name).tag(Optional($0)) }
                        }
                    } label: {
                        HStack {
                            if let selectedSubject {
                                Label(selectedSubject.name, systemImage: selectedSubject.iconName)
                            } else {
                                Text("Choose a subject")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(Color.primary)
                        .inputFieldStyle()
                    }
                    .accessibilityLabel("Subject")
                }

                // Week 12 feedback: deadlines can't be set in the past.
                DatePicker(
                    "Due date",
                    selection: $dueDate,
                    in: Calendar.current.startOfDay(for: .now)...,
                    displayedComponents: .date
                )
                .inputFieldStyle()

                Text("Priority / Weight")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(DeadlinePriority.allCases, id: \.self) { option in
                        Button {
                            priority = option
                        } label: {
                            Text(option.displayName)
                                .font(.spaceGrotesk(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(priority == option ? option.color : Color.secondary)
                                .background(priority == option ? option.color.opacity(0.15) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(priority == option ? option.color : Color.cardStroke))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(priority == option ? .isSelected : [])
                    }
                }

                Button("Add Deadline") { addDeadline() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(title.isBlank)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .font(.sgBody)
        .background(Color.appBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { selectedSubject = subject }
    }

    private func addDeadline() {
        let deadline = Deadline(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            priority: priority
        )
        deadline.subject = subject ?? selectedSubject
        modelContext.insert(deadline)
        dismiss()
    }
}
