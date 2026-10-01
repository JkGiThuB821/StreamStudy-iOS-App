//
//  ProgressDashboardVew.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

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
        return progressEntries.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.minutesSpent }
    }
    
    private var activeTopicsCount: Int {
        subjects.flatMap(\.topics).filter { $0.progress > 0 && !$0.isCompleted }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    statBlock(value: "\(overallProgress)%", label: "Overall")
                    statBlock(value: "\(totalMinutesThisWeek / 60)h \(totalMinutesThisWeek % 60)m", label: "This Week")
                    statBlock(value: "\(activeTopicsCount)", label: "Active")
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("By Subject").font(.sgHeadline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(subjects) { subject in
                            VStack {
                                ZStack {
                                    Circle().stroke(.white.opacity(0.15), lineWidth: 5)
                                    Circle()
                                        .trim(from: 0, to: subject.progress)
                                        .stroke(Color(hex: subject.colorHex), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    Text("\(Int(subject.progress * 100))%").font(.spaceGrotesk(size: 11, weight: .bold))
                                }
                                .frame(width: 56, height: 56)
                                Text(subject.name).font(.sgCaption2).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Study Activity").font(.sgHeadline)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                        .frame(height: 140)
                        .overlay(
                            Text("Swift Charts activity graph — Stage 6")
                                .font(.sgCaption)
                                .foregroundStyle(.secondary)
                        )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .navigationTitle("Progress")
    }
    
    private func statBlock(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.spaceGrotesk(size: 20, weight: .bold))
            Text(label).font(.sgCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
