//
//  ProgressDashboardVew.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData
import Charts

// Progress tab, laid out as in the UI design proposal (mock-up 7): three
// headline numbers, a ring per subject (filterable), and a study activity
// chart with a Week / Month toggle.
struct ProgressDashboardView: View {
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Query private var progressEntries: [StudyProgress]

    @State private var subjectFilter: UUID?          // nil = All
    @State private var range: ActivityRange = .week
    // The bar being touched (tap or drag across the chart); nil when not touching.
    @State private var selectedPeriod: String?

    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 190
    @ScaledMetric(relativeTo: .subheadline) private var ringSize: CGFloat = 64

    enum ActivityRange: Hashable { case week, month }

    private var calendar: Calendar { .current }

    // MARK: - Data

    private var visibleSubjects: [Subject] {
        guard let subjectFilter else { return subjects }
        return subjects.filter { $0.id == subjectFilter }
    }

    // Study sessions only (Swipe-to-Revise ratings have 0 minutes), for the filter.
    private var sessions: [StudyProgress] {
        progressEntries.filter { entry in
            guard entry.minutesSpent > 0 else { return false }
            guard let subjectFilter else { return true }
            return entry.topic?.subject?.id == subjectFilter
        }
    }

    private var overallProgress: Int {
        guard !subjects.isEmpty else { return 0 }
        let avg = subjects.map(\.progress).reduce(0, +) / Double(subjects.count)
        return Int(avg * 100)
    }

    private func minutes(from start: Date, to end: Date) -> Int {
        sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.minutesSpent }
    }

    private var thisWeekStart: Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: .now) ?? .now)
    }

    private var minutesThisWeek: Int {
        minutes(from: thisWeekStart, to: .now.addingTimeInterval(1))
    }

    private var minutesLastWeek: Int {
        let start = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
        return minutes(from: start, to: thisWeekStart)
    }

    private var activeTopics: (active: Int, total: Int) {
        let topics = subjects.flatMap(\.topics)
        return (topics.filter { $0.progress > 0 && !$0.isCompleted }.count, topics.count)
    }

    // Week: one bar per day for the last 7 days. Month: one bar per week for the last 4 weeks.
    private var bars: [ActivityBar] {
        switch range {
        case .week:
            return (0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: thisWeekStart),
                      let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                return ActivityBar(start: day, label: day.formatted(.dateTime.weekday(.abbreviated)), minutes: minutes(from: day, to: next))
            }
        case .month:
            return (0..<4).compactMap { offset in
                guard let start = calendar.date(byAdding: .day, value: -7 * (3 - offset), to: thisWeekStart),
                      let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
                return ActivityBar(start: start, label: start.formatted(.dateTime.day().month(.abbreviated)), minutes: minutes(from: start, to: end))
            }
        }
    }

    private var rangeTotal: Int { bars.reduce(0) { $0 + $1.minutes } }

    private var selectedBar: ActivityBar? {
        bars.first { $0.label == selectedPeriod }
    }

    // "Wed 28 Oct" for a day, "Week of 5 Oct" for a week.
    private func periodTitle(_ bar: ActivityBar) -> String {
        switch range {
        case .week: return bar.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .month: return "Week of \(bar.start.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }

    private func hoursAndMinutes(_ total: Int) -> String {
        total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total)m"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your study overview")
                    .font(.sgSubheadline)
                    .foregroundStyle(.secondary)

                AdaptiveStack(horizontalAlignment: .center, spacing: 10) {
                    StatBox(value: "\(overallProgress)%", label: "Overall", color: .red)
                    StatBox(value: hoursAndMinutes(minutesThisWeek), label: "This Week", color: .blue)
                    StatBox(value: "\(activeTopics.active)/\(activeTopics.total)", label: "Active", color: .green)
                }

                sectionHeader("By Subject")
                bySubjectCard

                HStack {
                    sectionHeader("Study Activity")
                    Spacer()
                    PillPicker(selection: $range, options: [(.week, "Week"), (.month, "Month")])
                        .frame(width: 150)
                }
                activityCard
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle("Progress")
    }

    // MARK: - By subject

    private var bySubjectCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", isSelected: subjectFilter == nil) { subjectFilter = nil }
                    ForEach(subjects) { subject in
                        filterChip(subject.name, isSelected: subjectFilter == subject.id) { subjectFilter = subject.id }
                    }
                }
            }

            if visibleSubjects.isEmpty {
                Text("Add a subject to start tracking progress.")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 18) {
                    ForEach(visibleSubjects) { subject in
                        VStack(spacing: 6) {
                            ProgressRing(progress: subject.progress, color: Color(hex: subject.colorHex), lineWidth: 6)
                                .frame(width: ringSize, height: ringSize)
                            Text(subject.name)
                                .font(.spaceGrotesk(size: 12, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            if let deadline = subject.nextDeadline {
                                Text(deadline.shortDueLabel)
                                    .font(.sgCaption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(.spaceGrotesk(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .expandedTapArea(.vertical, by: 8)
                .background(isSelected ? Color.red : Color.primary.opacity(0.08), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Filters the subject progress shown below")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Study activity

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptiveStack(verticalAlignment: .firstTextBaseline, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hoursAndMinutes(rangeTotal))
                        .font(.spaceGrotesk(size: 28, weight: .bold, relativeTo: .title))
                    Text(range == .week ? "this week" : "last 4 weeks")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if range == .week, let change = weekChangeText {
                    Text(change.text)
                        .font(.spaceGrotesk(size: 12, weight: .bold))
                        .foregroundStyle(change.isUp ? Color.green : Color.orange)
                }
            }

            Chart(bars) { bar in
                BarMark(
                    x: .value("Period", bar.label),
                    y: .value("Minutes", bar.minutes)
                )
                .foregroundStyle(Color.red.gradient)
                .cornerRadius(4)
                // While a bar is selected, the others fade so it stands out.
                .opacity(selectedBar == nil || selectedBar?.id == bar.id ? 1 : 0.35)
                .annotation(position: .top, spacing: 4) {
                    if bar.minutes > 0 && selectedBar == nil {
                        Text("\(bar.minutes)m")
                            .font(.spaceGrotesk(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Tap or drag across the chart: a guide line and a callout with the details.
                if let selectedBar, selectedBar.id == bar.id {
                    RuleMark(x: .value("Period", selectedBar.label))
                        .foregroundStyle(Color.primary.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(
                            position: .top,
                            spacing: 0,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            selectionCallout(selectedBar)
                        }
                }
            }
            .chartXSelection(value: $selectedPeriod)
            .chartYAxis(.hidden)
            .frame(height: chartHeight)
            .accessibilityLabel(range == .week ? "Minutes studied each day this week" : "Minutes studied each week")
            .onChange(of: range) { selectedPeriod = nil }

            Text("Tap or drag across the chart to see each \(range == .week ? "day" : "week").")
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardStyle()
    }

    private func selectionCallout(_ bar: ActivityBar) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(periodTitle(bar))
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
            Text(bar.minutes == 0 ? "No study" : hoursAndMinutes(bar.minutes))
                .font(.spaceGrotesk(size: 15, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke))
    }

    // "↑ 23% vs last week"
    private var weekChangeText: (text: String, isUp: Bool)? {
        guard minutesLastWeek > 0 else { return nil }
        let change = Double(minutesThisWeek - minutesLastWeek) / Double(minutesLastWeek) * 100
        let rounded = Int(change.rounded())
        return (rounded >= 0 ? "↑ \(rounded)% vs last week" : "↓ \(-rounded)% vs last week", rounded >= 0)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceGrotesk(size: 20, weight: .bold, relativeTo: .title3))
    }
}

private struct ActivityBar: Identifiable {
    let start: Date
    let label: String
    let minutes: Int
    var id: Date { start }
}
