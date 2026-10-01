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
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Mid-Semester Exam)", text: $title)
                    if subject == nil {
                        Picker("Subject", selection: $selectedSubject) {
                            Text("None").tag(Subject?.none)
                            ForEach(subjects) { Text($0.name).tag(Optional($0)) }
                        }
                        .font(.sgBody)
                    }
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Picker("Priority", selection: $priority) {
                        ForEach(DeadlinePriority.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .font(.sgBody)
            .navigationTitle("Add Deadline")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addDeadline() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { selectedSubject = subject }
        }
    }

    private func addDeadline() {
        let deadline = Deadline(title: title, dueDate: dueDate, priority: priority)
        deadline.subject = subject ?? selectedSubject
        modelContext.insert(deadline)
        dismiss()
    }
}
