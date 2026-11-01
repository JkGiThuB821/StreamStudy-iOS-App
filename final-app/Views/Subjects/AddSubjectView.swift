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

    // Spoken names for VoiceOver.
    private static let iconNames = [
        "iphone": "Phone", "cpu": "Chip", "brain.head.profile": "Brain", "globe": "Globe",
        "cylinder.split.1x2": "Database", "chevron.left.forwardslash.chevron.right": "Code", "lock.fill": "Lock",
    ]
    private static let colorNames = [
        "#E50914": "Red", "#2ECC71": "Green", "#E91E8C": "Pink",
        "#3498DB": "Blue", "#9B59B6": "Purple", "#F39C12": "Orange",
    ]

    @ScaledMetric(relativeTo: .body) private var iconTileSize: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var colorSwatchSize: CGFloat = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Add New Subject")
                        .font(.spaceGrotesk(size: 22, weight: .bold, relativeTo: .title2))
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.spaceGrotesk(size: 15, weight: .semibold))
                }

                TextField("Subject name", text: $name)
                    .characterLimit($name, TextLimits.name)
                    .inputFieldStyle()

                TextField("Short description", text: $description)
                    .characterLimit($description, TextLimits.shortDescription)
                    .inputFieldStyle()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: iconTileSize, height: iconTileSize)
                                    .foregroundStyle(selectedIcon == icon ? Color.white : Color.primary)
                                    .background(selectedIcon == icon ? Color.red : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(Self.iconNames[icon] ?? "Subject") icon")
                            .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(2)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Self.colors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: colorSwatchSize, height: colorSwatchSize)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == hex ? 2.5 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(Self.colorNames[hex] ?? "Custom") colour")
                            .accessibilityAddTraits(selectedColor == hex ? .isSelected : [])
                        }
                    }
                    .padding(4)
                }

                Button("Add Subject") { addSubject() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.isBlank)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .font(.sgBody)
        .background(Color.appBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
