//
//  AddResourceView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct AddResourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var topic: Topic

    @State private var title = ""
    @State private var urlString = ""
    @State private var sourceName = ""
    @State private var type: ResourceType = .video
    @State private var durationMinutes = 10

    private var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && isValidURL
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Resource") {
                    TextField("Title", text: $title)
                    TextField("URL (https://...)", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Source (e.g. YouTube, Apple Developer)", text: $sourceName)
                    Picker("Type", selection: $type) {
                        ForEach(ResourceType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 1...240)
                }
            }
            .font(.sgBody)
            .navigationTitle("Add Resource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addResource() }
                        .disabled(!isFormValid)
                }
            }
        }
    }

    private func addResource() {
        let resource = LearningResource(
            title: title,
            urlString: urlString,
            sourceName: sourceName.isEmpty ? "Manually added" : sourceName,
            type: type,
            durationMinutes: durationMinutes
        )
        resource.topic = topic
        modelContext.insert(resource)
        dismiss()
    }
}
