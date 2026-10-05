//
//  ProgressDashboardVew.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Query private var subjects: [Subject]
    @Query private var progressEntries: [StudyProgress]

    private var overallProgress: Int {
        guard !subjects.isEmpty else { return 0 }
        let avg = subjects.map(\.progress).reduce(0, +) / Double(subjects.count)
        return Int(avg * 100)
    }

    private var totalMinutesThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return progressEntries
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.minutesSpent }
    }

    private var activeTopicsCount: Int {
        subjects.flatMap(\.topics).filter { $0.progress > 0 && !$0.isCompleted }.count
    }

    private var weeklyActivity: [DailyStudy] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -6, to: .now) ?? .now
        )

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let minutes = progressEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.minutesSpent }

            return DailyStudy(date: date, minutes: minutes)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewCard

                sectionHeader("Subject Progress")
                subjectProgress

                sectionHeader("Study Activity")
                activityChart

                sectionHeader("Progress Breakdown")
                progressBars
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .navigationTitle("Progress")
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YOUR PROGRESS")
                .font(.spaceGrotesk(size: 12, weight: .bold))
                .foregroundStyle(.red)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(overallProgress)")
                    .font(.spaceGrotesk(size: 52, weight: .bold))
                Text("%")
                    .font(.spaceGrotesk(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Keep building consistent study habits across your subjects.")
                .font(.sgSubheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(overallProgress) / 100)
                .tint(.red)
                .scaleEffect(x: 1, y: 2, anchor: .center)

            HStack(spacing: 0) {
                metric(value: "\(totalMinutesThisWeek / 60)h \(totalMinutesThisWeek % 60)m", label: "This week")
                Divider().frame(height: 38)
                metric(value: "\(activeTopicsCount)", label: "Active topics")
                Divider().frame(height: 38)
                metric(value: "\(subjects.count)", label: "Subjects")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.red.opacity(0.25), .white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 8)
    }

    private var subjectProgress: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(subjects) { subject in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: subject.iconName)
                                .foregroundStyle(Color(hex: subject.colorHex))
                            Spacer()
                            Text("\(Int(subject.progress * 100))%")
                                .font(.spaceGrotesk(size: 18, weight: .bold))
                        }

                        Text(subject.name)
                            .font(.spaceGrotesk(size: 15, weight: .semibold))
                            .lineLimit(1)

                        ProgressView(value: subject.progress)
                            .tint(Color(hex: subject.colorHex))
                    }
                    .padding(16)
                    .frame(width: 170, alignment: .leading)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var activityChart: some View {
        Chart(weeklyActivity) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Minutes", day.minutes)
            )
            .foregroundStyle(.red.gradient)
            .cornerRadius(5)
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .frame(height: 190)
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var progressBars: some View {
        VStack(spacing: 14) {
            ForEach(subjects) { subject in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(subject.name)
                            .font(.spaceGrotesk(size: 14, weight: .semibold))
                        Spacer()
                        Text("\(Int(subject.progress * 100))%")
                            .font(.spaceGrotesk(size: 14, weight: .bold))
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.10))
                            Capsule()
                                .fill(Color(hex: subject.colorHex))
                                .frame(width: proxy.size.width * subject.progress)
                        }
                    }
                    .frame(height: 9)
                }
            }

            if subjects.isEmpty {
                Text("Add a subject to start tracking progress.")
                    .font(.sgCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceGrotesk(size: 20, weight: .bold))
            .padding(.top, 2)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.spaceGrotesk(size: 19, weight: .bold))
            Text(label)
                .font(.sgCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DailyStudy: Identifiable {
    let date: Date
    let minutes: Int
    var id: Date { date }
}
