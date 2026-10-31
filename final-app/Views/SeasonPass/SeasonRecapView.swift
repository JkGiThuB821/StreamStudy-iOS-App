//
//  SeasonRecapView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 22/10/2026.
//

import SwiftUI
import Charts

// The Season Recap "season finale" for one subject. Two complete presentations
// of the same recap:
//   - Story mode: full-screen cards with staged, animated reveals.
//   - Reduce Motion: a plain scrolling summary with no movement at all.
struct SeasonRecapView: View {
    let recap: SeasonRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            StaticRecapView(recap: recap)
        } else {
            StoryRecapView(recap: recap)
        }
    }
}

// MARK: - Cards

enum RecapCard: Hashable, CaseIterable {
    case intro, watchTime, binge, understanding, drops, themes, finale

    // Cards with nothing to show are skipped, so a new student's recap
    // never looks broken.
    static func cards(for recap: SeasonRecap) -> [RecapCard] {
        allCases.filter { card in
            switch card {
            case .binge: return recap.biggestWeek != nil
            case .drops: return recap.dropsFeatured > 0
            case .themes: return !recap.themes.isEmpty
            default: return true
            }
        }
    }
}

// MARK: - Story mode

private struct StoryRecapView: View {
    let recap: SeasonRecap

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var stage = 0

    private var cards: [RecapCard] { RecapCard.cards(for: recap) }
    private var color: Color { Color(hex: recap.colorHex) }
    private var isLast: Bool { index == cards.count - 1 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [color.opacity(index.isMultiple(of: 2) ? 0.95 : 0.7), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: index)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Spacer(minLength: 16)

                    RecapCardContent(card: cards[index], recap: recap, stage: stage, animated: true)
                        .id(index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .padding(.horizontal, 28)
                        .frame(maxWidth: 600)

                    Spacer(minLength: 16)

                    bottomBar
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                .foregroundStyle(.white)
            }
            .contentShape(Rectangle())
            // Tap the left third to go back, anywhere else to go forward.
            .onTapGesture { location in
                if location.x < geometry.size.width / 3 { previous() } else { next() }
            }
        }
        .statusBarHidden()
        .task(id: index) {
            // Staged reveal: each card's lines appear one after another.
            stage = 0
            for step in 1...4 {
                try? await Task.sleep(for: .milliseconds(step == 1 ? 150 : 450))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { stage = step }
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(cards.indices, id: \.self) { item in
                    Capsule()
                        .fill(.white.opacity(item <= index ? 0.95 : 0.3))
                        .frame(height: 3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Card \(index + 1) of \(cards.count)")

            HStack {
                Label(recap.subjectName, systemImage: recap.iconName)
                    .font(.spaceGrotesk(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .padding(8)
                        .background(.white.opacity(0.15), in: Circle())
                        .expandedTapArea(by: 6)
                }
                .accessibilityLabel("Close recap")
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("Back", action: previous)
                .opacity(index == 0 ? 0 : 1)
                .disabled(index == 0)
            Spacer()
            Button(isLast ? "Finish" : "Next") {
                if isLast { dismiss() } else { next() }
            }
            .fontWeight(.bold)
        }
        .font(.spaceGrotesk(size: 16, weight: .semibold))
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private func next() {
        guard index < cards.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
    }

    private func previous() {
        guard index > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) { index -= 1 }
    }
}

// MARK: - Reduce Motion: static summary

private struct StaticRecapView: View {
    let recap: SeasonRecap
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(RecapCard.cards(for: recap), id: \.self) { card in
                        RecapCardContent(card: card, recap: recap, stage: .max, animated: false)
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [Color(hex: recap.colorHex).opacity(0.85), .black], startPoint: .top, endPoint: .bottom)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("Season Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Card content (shared by both presentations)

private struct RecapCardContent: View {
    let card: RecapCard
    let recap: SeasonRecap
    let stage: Int
    let animated: Bool

    var body: some View {
        VStack(spacing: 18) {
            switch card {
            case .intro: intro
            case .watchTime: watchTime
            case .binge: binge
            case .understanding: understanding
            case .drops: drops
            case .themes: themes
            case .finale: finale
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Cards

    private var intro: some View {
        Group {
            Image(systemName: recap.iconName)
                .font(.system(size: 56, weight: .semibold))
                .reveal(stage >= 1)
            eyebrow("SEASON RECAP")
                .reveal(stage >= 1)
            Text(recap.subjectName)
                .font(.spaceGrotesk(size: 34, weight: .bold, relativeTo: .largeTitle))
                .reveal(stage >= 2)
            Text(recap.seasonStart.map { "Season 1 Â· since \($0.formatted(.dateTime.day().month(.wide)))" } ?? "Your season is just beginning")
                .font(.sgSubheadline)
                .opacity(0.8)
                .reveal(stage >= 3)
            if animated {
                Text("Tap to begin")
                    .font(.sgCaption)
                    .opacity(0.6)
                    .reveal(stage >= 4)
            }
        }
    }

    private var watchTime: some View {
        Group {
            eyebrow("YOUR WATCH TIME").reveal(stage >= 1)
            CountUpText(value: recap.totalMinutes, animated: animated)
                .font(.spaceGrotesk(size: 72, weight: .bold, relativeTo: .largeTitle))
                .reveal(stage >= 1)
            Text("minutes of \(recap.subjectName)")
                .font(.sgHeadline)
                .reveal(stage >= 2)

            if recap.totalEpisodes > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: Double(recap.episodesCompleted), total: Double(recap.totalEpisodes))
                        .tint(.white)
                    Text("\(recap.episodesCompleted) of \(recap.totalEpisodes) episodes finished")
                        .font(.sgSubheadline)
                }
                .reveal(stage >= 3)
            } else {
                Text("No episodes yet: find resources to start your season.")
                    .font(.sgSubheadline)
                    .opacity(0.8)
                    .reveal(stage >= 3)
            }
        }
    }

    @ViewBuilder
    private var binge: some View {
        eyebrow("YOUR BINGE CHART").reveal(stage >= 1)

        if let biggest = recap.biggestWeek {
            Chart(recap.weeklyMinutes) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Minutes", animated && stage < 2 ? 0 : week.minutes)
                )
                .foregroundStyle(week == biggest ? Color.white : Color.white.opacity(0.45))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.narrow))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 180)
            .accessibilityLabel("Minutes studied each week")

            Text("Biggest week: \(biggest.weekStart.formatted(.dateTime.day().month(.wide))), with \(biggest.minutes) minutes")
                .font(.sgHeadline)
                .reveal(stage >= 3)
        }
    }

    private var understanding: some View {
        Group {
            eyebrow("YOUR UNDERSTANDING ARC").reveal(stage >= 1)

            HStack(spacing: 28) {
                bigStat(recap.understoodTopics.count, label: "Got it")
                bigStat(recap.revisionTopics.count, label: "Revising")
            }
            .reveal(stage >= 2)

            if recap.ratingsCount == 0 {
                Text("Swipe to rate your topics and your arc will appear here.")
                    .font(.sgSubheadline)
                    .opacity(0.8)
                    .reveal(stage >= 3)
            } else {
                Text("\(recap.ratingsCount) swipe\(recap.ratingsCount == 1 ? "" : "s") this season")
                    .font(.sgSubheadline)
                    .opacity(0.8)
                    .reveal(stage >= 3)
            }

            if !recap.turnedAroundTopics.isEmpty {
                Label("You turned around: \(recap.turnedAroundTopics.joined(separator: ", "))", systemImage: "arrow.up.forward.circle.fill")
                    .font(.sgHeadline)
                    .reveal(stage >= 4)
            }
        }
    }

    private var drops: some View {
        Group {
            eyebrow("WEEKLY DROPS").reveal(stage >= 1)
            CountUpText(value: recap.dropsFeatured, animated: animated)
                .font(.spaceGrotesk(size: 72, weight: .bold, relativeTo: .largeTitle))
                .reveal(stage >= 1)
            Text("weekly drop\(recap.dropsFeatured == 1 ? "" : "s") featured \(recap.subjectName)")
                .font(.sgHeadline)
                .reveal(stage >= 2)
            if recap.featuredEpisodesTotal > 0 {
                Text("You finished \(recap.featuredEpisodesCompleted) of the \(recap.featuredEpisodesTotal) episodes picked for you.")
                    .font(.sgSubheadline)
                    .opacity(0.85)
                    .reveal(stage >= 3)
            }
        }
    }

    private var themes: some View {
        Group {
            eyebrow("YOUR SEASON'S THEMES").reveal(stage >= 1)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(Array(recap.themes.enumerated()), id: \.element) { position, theme in
                    Text(theme)
                        .font(.spaceGrotesk(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.18), in: Capsule())
                        .reveal(stage >= min(position + 2, 4))
                }
            }
            Text("Tagged from the episodes you watched this season.")
                .font(.sgCaption)
                .opacity(0.7)
                .reveal(stage >= 4)
        }
    }

    private var finale: some View {
        Group {
            eyebrow("SEASON FINALE").reveal(stage >= 1)

            if let title = recap.nextDeadlineTitle, let days = recap.nextDeadlineDays {
                Text(days <= 0 ? "\(title) is today" : "\(title) in \(days) day\(days == 1 ? "" : "s")")
                    .font(.spaceGrotesk(size: 28, weight: .bold, relativeTo: .title))
                    .reveal(stage >= 2)
            } else {
                Text("Keep the season going")
                    .font(.spaceGrotesk(size: 28, weight: .bold, relativeTo: .title))
                    .reveal(stage >= 2)
            }

            if recap.upNextTopics.isEmpty {
                Text("Every topic is wrapped up. Nice work!")
                    .font(.sgHeadline)
                    .reveal(stage >= 3)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Revise these first:")
                        .font(.sgSubheadline)
                        .opacity(0.8)
                    ForEach(Array(recap.upNextTopics.enumerated()), id: \.offset) { position, title in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(position + 1)")
                                .font(.spaceGrotesk(size: 15, weight: .bold))
                                .frame(width: 26, height: 26)
                                .background(.white.opacity(0.2), in: Circle())
                            Text(title)
                                .font(.sgHeadline)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .reveal(stage >= 3)
            }
        }
    }

    // MARK: Pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.spaceGrotesk(size: 13, weight: .bold))
            .tracking(1.5)
            .opacity(0.75)
    }

    private func bigStat(_ value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            CountUpText(value: value, animated: animated)
                .font(.spaceGrotesk(size: 56, weight: .bold, relativeTo: .largeTitle))
            Text(label)
                .font(.sgSubheadline)
                .opacity(0.8)
        }
    }
}

// A number that counts up from 0 when it appears (or shows the final value
// straight away when not animated).
private struct CountUpText: View {
    let value: Int
    let animated: Bool
    @State private var shown = 0

    var body: some View {
        Text("\(animated ? shown : value)")
            .contentTransition(.numericText(value: Double(animated ? shown : value)))
            .onAppear {
                guard animated else { return }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) { shown = value }
            }
            .accessibilityLabel("\(value)")
    }
}

private extension View {
    // Fades and slides content in for the staged reveal.
    func reveal(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
    }
}
