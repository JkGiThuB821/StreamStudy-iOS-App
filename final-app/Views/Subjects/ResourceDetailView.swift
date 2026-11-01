//
//  ResourceDetailView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/10/2026.
//

import SwiftUI
import SwiftData

// One learning resource (an "episode"): thumbnail, completion, bookmark, the
// student's notes, and the topic's other resources. Matches mock-up 12.
struct ResourceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var resource: LearningResource

    private var otherResources: [LearningResource] {
        (resource.topic?.resources ?? [])
            .filter { $0.id != resource.id }
            .sorted { ($0.addedAt, $0.title) < ($1.addedAt, $1.title) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        BadgeLabel(text: resource.sourceBadge.text, color: resource.sourceBadge.color, filled: false)
                        if let topic = resource.topic {
                            Text("from \(topic.title)")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(resource.title)
                        .font(.spaceGrotesk(size: 24, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Label("\(resource.durationMinutes) min", systemImage: "clock")
                            .foregroundStyle(.secondary)
                        if let subject = resource.topic?.subject {
                            Label(subject.name, systemImage: subject.iconName)
                                .foregroundStyle(Color(hex: subject.colorHex))
                                .lineLimit(1)
                        }
                    }
                    .font(.sgCaption)
                }

                actions

                notes

                if !otherResources.isEmpty {
                    moreFromEpisode
                }
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .tabBarClearance()
        .navigationTitle(resource.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        Button(action: open) {
            ResourceThumbnail(resource: resource)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.red, in: Circle())
                }
                .overlay(alignment: .bottomTrailing) {
                    Text("\(resource.durationMinutes) min")
                        .font(.spaceGrotesk(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(resource.title)")
    }

    // MARK: - Completed + bookmark

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleCompleted() }
                } label: {
                    Label(resource.isCompleted ? "Completed" : "Mark as Complete",
                          systemImage: resource.isCompleted ? "checkmark" : "circle")
                        .font(.spaceGrotesk(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(resource.isCompleted ? Color.green : Color.primary)
                        .background((resource.isCompleted ? Color.green : Color.primary).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(resource.isCompleted ? Color.green : Color.cardStroke, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Button {
                    resource.isSaved.toggle()
                } label: {
                    Image(systemName: resource.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 54, height: 50)
                        .cardStyle(cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save for later")
                .accessibilityValue(resource.isSaved ? "Saved" : "Not saved")
                .accessibilityHint(resource.isSaved ? "Removes this resource from your saved list" : "Adds this resource to your saved list")
            }

            Button(action: open) {
                Label(resource.sourceName.localizedCaseInsensitiveContains("youtube") ? "Watch on YouTube" : "Open in Safari",
                      systemImage: "arrow.up.right.square")
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }

    // MARK: - Notes

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Notes")
                .font(.spaceGrotesk(size: 18, weight: .bold, relativeTo: .headline))

            TextEditor(text: $resource.notes)
                .font(.sgBody)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(8)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardStroke))
                .overlay(alignment: .topLeading) {
                    if resource.notes.isEmpty {
                        Text("Write down what you want to remember…")
                            .font(.sgBody)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .characterLimit($resource.notes, TextLimits.notes)
                .accessibilityLabel("My notes")
        }
    }

    // MARK: - More from this episode

    private var moreFromEpisode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More from this Episode")
                .font(.spaceGrotesk(size: 18, weight: .bold, relativeTo: .headline))

            ForEach(otherResources) { other in
                NavigationLink {
                    ResourceDetailView(resource: other)
                } label: {
                    HStack(spacing: 12) {
                        ResourceThumbnail(resource: other)
                            .frame(width: 64, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(other.title)
                                .font(.spaceGrotesk(size: 14, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text("\(other.durationMinutes) min")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if other.isCompleted {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .padding(10)
                    .cardStyle(cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func open() {
        if let url = URL(string: resource.urlString) { openURL(url) }
    }

    private func toggleCompleted() {
        if let topic = resource.topic {
            // Also logs (or removes) study time for the Progress charts.
            topic.toggleCompletion(of: resource, modelContext: modelContext)
        } else {
            resource.isCompleted.toggle()
        }
    }
}

// MARK: - Thumbnail

// The video thumbnail when there is one, otherwise a tinted tile with the type's icon.
struct ResourceThumbnail: View {
    let resource: LearningResource

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [resource.sourceBadge.color.opacity(0.55), resource.sourceBadge.color.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: resource.type.sfSymbol)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))

            if let thumbnail = resource.thumbnailURLString, let url = URL(string: thumbnail) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Source badge

extension LearningResource {
    // "YouTube", "Docs" or "Article", with a colour, as in the mock-ups.
    var sourceBadge: (text: String, color: Color) {
        if sourceName.localizedCaseInsensitiveContains("youtube") { return ("YouTube", .red) }
        switch type {
        case .video: return ("Video", .red)
        case .documentation: return ("Docs", .green)
        case .article: return ("Article", .blue)
        }
    }
}
