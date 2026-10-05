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
            VStack(alignment: .leading, spacing: 18) {
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

    private var monthSwitcher: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.spaceGrotesk(size: 20, weight: .bold))
                Text("\(monthDeadlineCount) deadlines")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }

    private var monthGrid: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.spaceGrotesk(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 9
            ) {
                ForEach(daysInMonth(), id: \.id) { day in
                    dayCell(day)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(day.date)

        return Button {
            selectedDate = day.date
        } label: {
            VStack(spacing: 5) {
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.spaceGrotesk(size: 14, weight: isSelected || isToday ? .bold : .regular))
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(.red)
                        } else if isToday {
                            Circle().stroke(.red, lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 3) {
                    ForEach(Array(day.priorities.prefix(3).enumerated()), id: \.offset) { _, priority in
                        Circle()
                            .fill(priorityColor(priority))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .opacity(day.isInDisplayedMonth ? 1 : 0.25)
    }

    private var selectedDayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.spaceGrotesk(size: 21, weight: .bold))
                Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(selectedDeadlines.count)")
                .font(.spaceGrotesk(size: 32, weight: .bold))
                .foregroundStyle(.red)
            Text("due")
                .font(.sgCaption)
                .foregroundStyle(.secondary)
        }
    }

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
                        .font(.spaceGrotesk(size: 15, weight: .semibold))
                    Text("Use this day to build some progress.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func deadlineCard(_ deadline: Deadline) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(priorityColor(deadline.priority))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.spaceGrotesk(size: 15, weight: .bold))
                Text(deadline.subject?.name ?? "General")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(priorityLabel(deadline.priority))
                .font(.spaceGrotesk(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(priorityColor(deadline.priority).opacity(0.16))
                .foregroundStyle(priorityColor(deadline.priority))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(deadline)
            } label: {
                Label("Delete Deadline", systemImage: "trash")
            }
        }
    }

    private var monthDeadlineCount: Int {
        deadlines.filter {
            Calendar.current.isDate($0.dueDate, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    private func daysInMonth() -> [CalendarDay] {
        let calendar = Calendar.current
        guard let firstOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
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

            let isInDisplayedMonth = calendar.isDate(
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
        ) else { return }

        displayedMonth = month
        selectedDate = month
    }

    private func priorityColor(_ priority: DeadlinePriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }

    private func priorityLabel(_ priority: DeadlinePriority) -> String {
        priority.displayName.uppercased()
    }

    private func handleDeepLink() {
        guard case .calendar(let deadlineID) = deepLinkRouter.destination else { return }

        if let deadlineID,
           let deadline = deadlines.first(where: { $0.id == deadlineID }) {
            displayedMonth = deadline.dueDate
            selectedDate = deadline.dueDate
        } else {
            selectedDate = .now
        }

        deepLinkRouter.clear()
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let priorities: [DeadlinePriority]

    var id: Date { date }

    init(date: Date, isInDisplayedMonth: Bool, deadlines: [Deadline]) {
        self.date = date
        self.isInDisplayedMonth = isInDisplayedMonth
        self.priorities = deadlines
            .filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
            .map(\.priority)
    }
}
