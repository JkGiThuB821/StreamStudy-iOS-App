//
//  CalendarView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]

    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now
    @State private var showingAddDeadline = false
    // True after tapping a day: the list shows only that day's deadlines.
    @State private var showsSelectedDayOnly = false

    @ScaledMetric(relativeTo: .footnote) private var dayCircleSize: CGFloat = 38
    @ScaledMetric(relativeTo: .footnote) private var dayCellHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .footnote) private var monthButtonSize: CGFloat = 32

    private var selectedDeadlines: [Deadline] {
        deadlines.filter {
            Calendar.current.isDate($0.dueDate, inSameDayAs: selectedDate)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Deadlines & assessments")
                    .font(.sgSubheadline)
                    .foregroundStyle(.secondary)

                monthSwitcher

                VStack(spacing: 12) {
                    monthGrid
                }
                .padding(.vertical, 12)
                .cardStyle()

                priorityLegend

                upcomingSection
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color.appBackground)
        .tabBarClearance()   // keeps the last item clear of the tab bar
        .navigationTitle("Calendar")
        .sheet(isPresented: $showingAddDeadline) {
            AddDeadlineView(subject: nil)
        }
        .onAppear {
            handleDeepLink()
        }
        .onChange(of: deepLinkRouter.destination) { _, _ in
            handleDeepLink()
        }
    }

    // MARK: - Month Header

    private var monthSwitcher: some View {
        HStack {
            monthButton(systemImage: "chevron.left", label: "Previous month") { changeMonth(by: -1) }
            Spacer()
            Text(monthTitle)
                .font(.spaceGrotesk(size: 20, weight: .bold, relativeTo: .title3))
            Spacer()
            monthButton(systemImage: "chevron.right", label: "Next month") { changeMonth(by: 1) }
        }
    }

    private func monthButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.bold())
                .frame(width: monthButtonSize, height: monthButtonSize)
                .expandedTapArea(by: 6)   // 44pt hit target
                .cardStyle(cornerRadius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // Low / Medium / High dots, as in the mock-up.
    private var priorityLegend: some View {
        HStack(spacing: 14) {
            ForEach(DeadlinePriority.allCases, id: \.self) { priority in
                HStack(spacing: 5) {
                    Circle().fill(priority.color).frame(width: 7, height: 7)
                    Text("\(priority.displayName) Priority")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Calendar Grid

    private var monthGrid: some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(
                    Array(
                        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                            .enumerated()
                    ),
                    id: \.offset
                ) { _, day in
                    Text(day)
                        .font(
                            .spaceGrotesk(
                                size: 11,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: 4
                    ),
                    count: 7
                ),
                spacing: 12
            ) {
                ForEach(
                    daysInMonth(),
                    id: \.id
                ) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = Calendar.current.isDate(
            day.date,
            inSameDayAs: selectedDate
        )

        let isToday = Calendar.current.isDateInToday(
            day.date
        )

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = day.date
                showsSelectedDayOnly = true
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isSelected
                                ? Color.red
                                : Color.clear
                        )
                        .frame(
                            width: dayCircleSize,
                            height: dayCircleSize
                        )

                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                .red,
                                lineWidth: 1.5
                            )
                            .frame(
                                width: dayCircleSize,
                                height: dayCircleSize
                            )
                    }

                    Text("\(Calendar.current.component(.day, from: day.date))"
                    )
                    .font(
                        .spaceGrotesk(
                            size: 14,
                            weight: isSelected || isToday
                                ? .bold
                                : .medium
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                }

                HStack(spacing: 3) {
                    ForEach(
                        Array(
                            day.priorities
                                .prefix(3)
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, priority in
                        Circle()
                            .fill(
                                priorityColor(priority)
                            )
                            .frame(
                                width: 5,
                                height: 5
                            )
                    }
                }
                .frame(height: 5)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: dayCellHeight
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(dayAccessibilityValue(day, isToday: isToday))
        .accessibilityHint("Shows the deadlines for this day")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .opacity(
            day.isInDisplayedMonth
                ? 1
                : 0.22
        )
    }

    // VoiceOver can't see the priority dots, so describe them in words.
    private func dayAccessibilityValue(_ day: CalendarDay, isToday: Bool) -> String {
        var parts: [String] = []
        if isToday { parts.append("Today") }
        if day.priorities.isEmpty {
            parts.append("No deadlines")
        } else {
            let count = day.priorities.count
            let names = day.priorities.map(\.displayName).joined(separator: ", ")
            parts.append("\(count) deadline\(count == 1 ? "" : "s"), \(names) priority")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Upcoming Deadlines

    private var upcomingDeadlines: [Deadline] {
        deadlines.filter { !$0.isOverdue }
    }

    private var listedDeadlines: [Deadline] {
        showsSelectedDayOnly ? selectedDeadlines : upcomingDeadlines
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(showsSelectedDayOnly ? selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)) : "Upcoming Deadlines")
                        .font(.spaceGrotesk(size: 20, weight: .bold, relativeTo: .title3))
                    if showsSelectedDayOnly {
                        Button("Show all upcoming") {
                            withAnimation { showsSelectedDayOnly = false }
                        }
                        .font(.sgCaption)
                    }
                }
                Spacer()
                Button {
                    showingAddDeadline = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.spaceGrotesk(size: 14, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Add deadline")
            }

            ForEach(listedDeadlines) { deadline in
                deadlineCard(deadline)
            }

            if listedDeadlines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text(showsSelectedDayOnly ? "Nothing due on this day" : "No upcoming deadlines")
                        .font(.spaceGrotesk(size: 15, weight: .semibold))
                    Text("Use the time to build some progress.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .cardStyle()
            }
        }
    }

    private func deadlineCard(_ deadline: Deadline) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(deadline.priority.color)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(deadline.title)
                    .font(.spaceGrotesk(size: 16, weight: .bold))
                    .lineLimit(3)
                Text(deadline.subject?.name ?? "General")
                    .font(.sgCaption)
                    .foregroundStyle(deadline.subject.map { Color(hex: $0.colorHex) } ?? Color.secondary)
                Text(deadline.dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.sgCaption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(daysLeftText(deadline))
                    .font(.spaceGrotesk(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                BadgeLabel(text: deadline.priority.displayName, color: deadline.priority.color, filled: false)
            }
        }
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Touch and hold for more options")
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(deadline)
            } label: {
                Label("Delete Deadline", systemImage: "trash")
            }
        }
    }

    private func daysLeftText(_ deadline: Deadline) -> String {
        switch deadline.daysRemaining {
        case ...0: return "Today"
        case 1: return "1 day"
        default: return "\(deadline.daysRemaining) days"
        }
    }

    // MARK: - Calendar Data

    private var monthDeadlineCount: Int {
        deadlines.filter {
            Calendar.current.isDate(
                $0.dueDate,
                equalTo: displayedMonth,
                toGranularity: .month
            )
        }
        .count
    }

    private func daysInMonth() -> [CalendarDay] {
        let calendar = Calendar.current

        guard let firstOfMonth = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: displayedMonth
            )
        ) else {
            return []
        }

        let firstWeekday =
            calendar.component(
                .weekday,
                from: firstOfMonth
            ) - 1

        let gridStart = calendar.date(
            byAdding: .day,
            value: -firstWeekday,
            to: firstOfMonth
        ) ?? firstOfMonth

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(
                byAdding: .day,
                value: offset,
                to: gridStart
            ) else {
                return nil
            }

            let isInDisplayedMonth =
                calendar.isDate(
                    date,
                    equalTo: displayedMonth,
                    toGranularity: .month
                )

            return CalendarDay(
                date: date,
                isInDisplayedMonth: isInDisplayedMonth,
                deadlines: deadlines
            )
        }
    }

    private func changeMonth(by value: Int) {
        guard let month = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) else {
            return
        }

        displayedMonth = month
        selectedDate = month
    }

    // MARK: - Priority

    private func priorityColor(
        _ priority: DeadlinePriority
    ) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .red
        }
    }

    private func priorityLabel(
        _ priority: DeadlinePriority
    ) -> String {
        priority.displayName.uppercased()
    }

    // MARK: - Deep Linking

    private func handleDeepLink() {
        guard case .calendar(let deadlineID) =
                deepLinkRouter.destination
        else {
            return
        }

        if let deadlineID,
           let deadline = deadlines.first(
               where: { $0.id == deadlineID }
           ) {
            displayedMonth = deadline.dueDate
            selectedDate = deadline.dueDate
            showsSelectedDayOnly = true
        } else {
            selectedDate = .now
        }

        deepLinkRouter.clear()
    }
}

// MARK: - Calendar Day Model

private struct CalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let priorities: [DeadlinePriority]

    var id: Date {
        date
    }

    init(
        date: Date,
        isInDisplayedMonth: Bool,
        deadlines: [Deadline]
    ) {
        self.date = date
        self.isInDisplayedMonth = isInDisplayedMonth

        self.priorities = deadlines
            .filter {
                Calendar.current.isDate(
                    $0.dueDate,
                    inSameDayAs: date
                )
            }
            .map(\.priority)
    }
}
