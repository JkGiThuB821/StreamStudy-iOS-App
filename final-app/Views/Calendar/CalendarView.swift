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
    @Query(sort: \Deadline.dueDate) private var deadlines: [Deadline]
    @State private var displayedMonth = Date.now
    @State private var showingAddDeadline = false

    private var upcoming: [Deadline] {
        deadlines.filter { !$0.isOverdue }
    }

    var body: some View {
        ScrollView {
            monthHeader

            monthGrid

            legendRow

            HStack {
                Text("Upcoming Deadlines").font(.sgHeadline)
                Spacer()
                Button(action: { showingAddDeadline = true }) {
                    Label("Add", systemImage: "plus").font(.spaceGrotesk(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVStack(spacing: 8) {
                ForEach(upcoming) { deadline in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(deadline.title).font(.spaceGrotesk(size: 15, weight: .bold))
                            Text(deadline.subject?.name ?? "General")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(deadline.daysRemaining)d")
                            .font(.sgCaption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(priorityColor(deadline.priority).opacity(0.25))
                            .foregroundStyle(priorityColor(deadline.priority))
                            .clipShape(Capsule())
                    }
                    .padding()
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(deadline)
                        } label: {
                            Label("Delete Deadline", systemImage: "trash")
                        }
                    }
                }

                if upcoming.isEmpty {
                    Text("No upcoming deadlines.")
                        .font(.sgCaption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .navigationTitle("Calendar")
        .sheet(isPresented: $showingAddDeadline) { AddDeadlineView(subject: nil) }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.sgHeadline)
            Spacer()
            Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
        }
        .padding()
    }

    private var monthGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) {
                Text($0).font(.sgCaption2).foregroundStyle(.secondary)
            }
            ForEach(days, id: \.self) { date in
                if let date {
                    let dayDeadlines = deadlines.filter {
                        Calendar.current.isDate($0.dueDate, inSameDayAs: date)
                    }
                    VStack(spacing: 2) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.sgCaption)
                        if let first = dayDeadlines.first {
                            Circle().fill(priorityColor(first.priority)).frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 28)
                } else {
                    Color.clear.frame(minHeight: 28)
                }
            }
        }
        .padding(.horizontal)
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendDot(.green, "Low Priority")
            legendDot(.yellow, "Medium Priority")
            legendDot(.red, "High Priority")
        }
        .font(.sgCaption2)
        .padding(.top, 10)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }

    private func priorityColor(_ priority: DeadlinePriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

        private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        days += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth) }
        return days
    }
}
