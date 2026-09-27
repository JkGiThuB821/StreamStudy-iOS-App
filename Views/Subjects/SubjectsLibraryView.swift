//
//  SubjectsLibraryView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import SwiftUI
import SwiftData

struct SubjectsLibraryView: View {
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @State private var searchText = ""
    @State private var showingAddSubject = false

    private var filteredSubjects: [Subject] {
        guard !searchText.isEmpty else { return subjects }
        return subjects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var averageProgress: Int {
        guard !subjects.isEmpty else { return 0 }
        let avg = subjects.map(\.progress).reduce(0, +) / Double(subjects.count)
        return Int(avg * 100)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            statsHeader

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredSubjects) { subject in
                    NavigationLink(value: subject) {
                        subjectCard(subject)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showingAddSubject = true }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.title)
                        Text("Add Subject").font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(.white.opacity(0.06))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .searchable(text: $searchText, prompt: "Search subjects...")
        .background(Color.black)
        .navigationTitle("Subjects Library")
        .navigationDestination(for: Subject.self) { SubjectDetailView(subject: $0) }
        .sheet(isPresented: $showingAddSubject) { AddSubjectView() }
    }

    private var statsHeader: some View {
        HStack {
            statBlock(value: "\(subjects.count)", label: "Subjects")
            statBlock(value: "\(subjects.filter { $0.progress > 0 && $0.progress < 1 }.count)", label: "In Progress")
            statBlock(value: "\(averageProgress)%", label: "Avg Progress")
        }
        .padding()
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func subjectCard(_ subject: Subject) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: subject.iconName)
                Spacer()
                Text("\(Int(subject.progress * 100))%")
                    .font(.caption2.bold())
            }
            Spacer()
            Text(subject.name)
                .font(.subheadline.bold())
                .lineLimit(2)
            Text(subject.subjectDescription)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(10)
        .frame(height: 110, alignment: .leading)
        .background(Color(hex: subject.colorHex).opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
