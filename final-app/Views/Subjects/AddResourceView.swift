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
        !title.isBlank && isValidURL
    }

    // Links from known video sites. Anything else can't be checked, so the
    // type the user picks is trusted.
    private var isVideoLink: Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return ["youtube.com", "youtu.be", "vimeo.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .characterLimit($title, TextLimits.title)
                    TextField("URL (https://...)", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .characterLimit($urlString, TextLimits.url)
                    TextField("Source (e.g. YouTube, Apple Developer)", text: $sourceName)
                        .characterLimit($sourceName, TextLimits.name)
                    Picker("Type", selection: $type) {
                        ForEach(ResourceType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 1...240)
                } header: {
                    Text("New Resource")
                } footer: {
                    if isVideoLink && type != .video {
                        Label("This looks like a video link. Consider setting the type to Video.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Only YouTube and Vimeo links are recognised automatically. For other links, please choose the type that matches.")
                    }
                }
            }
            // Picks Video automatically when a video link is pasted.
            .onChange(of: urlString) {
                if isVideoLink { type = .video }
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

        // Tag the new resource in the background (AI, or metadata if offline).
        let topic = topic
        Task { await ResourceTaggingService.tagUntaggedResources(in: topic) }
        dismiss()
    }
}
