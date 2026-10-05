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
            VStack(alignment: .leading, spacing: 22) {
                monthSwitcher
                monthGrid

                selectedDayHeader
                selectedDeadlineList
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddDeadline = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        displayedMonth.formatted(
                            .dateTime.month(.wide)
                        )
                    )
                    .font(
                        .spaceGrotesk(
                            size: 28,
                            weight: .bold
                        )
                    )

                    Text(
                        displayedMonth.formatted(
                            .dateTime.year()
                        )
                    )
                    .font(
                        .spaceGrotesk(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
//                    Button {
//                        displayedMonth = .now
//                        selectedDate = .now
//                    } label: {
//                        Text("Today")
//                            .font(
//                                .spaceGrotesk(
//                                    size: 12,
//                                    weight: .semibold
//                                )
//                            )
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 8)
//                            .background(.white.opacity(0.08))
//                            .clipShape(Capsule())
//                    }
//                    .buttonStyle(.plain)

                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)

                Text("\(monthDeadlineCount) deadlines this month")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Calendar Grid

    private var monthGrid: some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(
                    Array(
                        ["S", "M", "T", "W", "T", "F", "S"]
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
                            width: 38,
                            height: 38
                        )

                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                .red,
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 38,
                                height: 38
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
                minHeight: 56
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .opacity(
            day.isInDisplayedMonth
                ? 1
                : 0.22
        )
    }

    // MARK: - Selected Day

    private var selectedDayHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    selectedDate.formatted(
                        .dateTime.weekday(.wide)
                    )
                )
                .font(
                    .spaceGrotesk(
                        size: 24,
                        weight: .bold
                    )
                )

                Text(
                    selectedDate.formatted(
                        .dateTime.day().month(.wide)
                    )
                )
                .font(.sgCaption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(selectedDeadlines.count)")
                    .font(
                        .spaceGrotesk(
                            size: 30,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.red)

                Text(
                    selectedDeadlines.count == 1
                        ? "deadline"
                        : "deadlines"
                )
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Deadline List

    private var selectedDeadlineList: some View {
        VStack(spacing: 10) {
            ForEach(selectedDeadlines) { deadline in
                deadlineCard(deadline)
            }

            if selectedDeadlines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)

                    Text("Nothing due today")
                        .font(
                            .spaceGrotesk(
                                size: 15,
                                weight: .semibold
                            )
                        )

                    Text("Use this day to build some progress.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    .white.opacity(0.05)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )
            }
        }
    }

    private func deadlineCard(
        _ deadline: Deadline
    ) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    priorityColor(deadline.priority)
                )
                .frame(width: 5)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(deadline.title)
                    .font(
                        .spaceGrotesk(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold
                            )
                        )

                    Text(
                        deadline.subject?.name
                            ?? "General"
                    )
                    .font(.sgCaption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 5
            ) {
                Text(
                    priorityLabel(
                        deadline.priority
                    )
                )
                .font(
                    .spaceGrotesk(
                        size: 10,
                        weight: .bold
                    )
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    priorityColor(
                        deadline.priority
                    )
                    .opacity(0.14)
                )
                .foregroundStyle(
                    priorityColor(
                        deadline.priority
                    )
                )
                .clipShape(Capsule())

                Text(
                    deadline.dueDate.formatted(
                        .dateTime.hour().minute()
                    )
                )
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                .white.opacity(0.055)
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                .white.opacity(0.06),
                lineWidth: 1
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(deadline)
            } label: {
                Label(
                    "Delete Deadline",
                    systemImage: "trash"
                )
            }
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
