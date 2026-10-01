//
//  AddSubjectView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct AddSubjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = icons.first!
    @State private var selectedColor = colors.first!

    private static let icons = [
        "iphone", "cpu", "brain.head.profile", "globe",
        "cylinder.split.1x2", "chevron.left.forwardslash.chevron.right", "lock.fill",
    ]
    private static let colors = ["#E50914", "#2ECC71", "#E91E8C", "#3498DB", "#9B59B6", "#F39C12"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Add New Subject") {
                    TextField("Subject name", text: $name)
                    TextField("Short description", text: $description)
                }

                Section("Icon") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Self.icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .padding(10)
                                    .background(selectedIcon == icon ? Color.accentColor : .gray.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { selectedIcon = icon }
                            }
                        }
                    }
                }

                Section("Color") {
                    HStack {
                        ForEach(Self.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: selectedColor == hex ? 2 : 0)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                }

                Button("Add Subject") {
                    addSubject()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.sgBody)
            .navigationTitle("New Subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addSubject() {
        let subject = Subject(
            name: name,
            subjectDescription: description,
            colorHex: selectedColor,
            iconName: selectedIcon
        )
        modelContext.insert(subject)
        dismiss()
    }
}
