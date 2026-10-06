//
//  MainTabView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//

import SwiftUI
import SwiftData

struct MainTabView: View {

    enum Tab: Hashable {
        case home
        case subjects
        case calendar
        case progress
        case profile
    }

    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @Query private var topics: [Topic]
    @Query private var deadlines: [Deadline]

    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()

    // Changes whenever a deadline is added, removed or edited, so reminders get rescheduled.
    private var deadlineSignature: [String] {
        deadlines.map { "\($0.id)-\($0.title)-\($0.dueDate.timeIntervalSince1970)" }
    }

    var body: some View {

        TabView(selection: $selectedTab) {

            // MARK: Home

            NavigationStack(path: $homePath) {
                HomeView()
            }
            .tag(Tab.home)
            .tabItem {
                EmptyView()
            }

            // MARK: Subjects

            NavigationStack {
                SubjectsLibraryView()
            }
            .tag(Tab.subjects)
            .tabItem {
                EmptyView()
            }

            // MARK: Calendar

            NavigationStack {
                CalendarView()
            }
            .tag(Tab.calendar)
            .tabItem {
                EmptyView()
            }

            // MARK: Progress

            NavigationStack {
                ProgressDashboardView()
            }
            .tag(Tab.progress)
            .tabItem {
                EmptyView()
            }

            // MARK: Profile

            NavigationStack {
                AccountView()
            }
            .tag(Tab.profile)
            .tabItem {
                EmptyView()
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
        .task(id: deadlineSignature) {
            // Only prompts the first time; afterwards it returns the saved choice immediately.
            await NotificationService.shared.requestPermission()
            await NotificationService.shared.scheduleNotifications(for: deadlines)
        }
        .onAppear {
            route(deepLinkRouter.destination)
        }
        .onChange(of: deepLinkRouter.destination) { _, destination in
            route(destination)
        }
    }

    // MARK: Deep Linking

    private func route(_ destination: DeepLinkRouter.Destination?) {
        switch destination {
        case .topic(let id):
            selectedTab = .home
            homePath = NavigationPath()
            if let topic = topics.first(where: { $0.id == id }) {
                homePath.append(topic)
            }
            deepLinkRouter.clear()
        case .calendar:
            // CalendarView reads the deadline ID and clears the destination itself.
            selectedTab = .calendar
        case nil:
            break
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {

    @Binding var selectedTab: MainTabView.Tab

    var body: some View {

        HStack(spacing: 0) {

            tabButton(
                tab: .home,
                icon: "house.fill",
                label: "Home"
            )

            tabButton(
                tab: .subjects,
                icon: "square.grid.2x2.fill",
                label: "Subjects"
            )

            tabButton(
                tab: .calendar,
                icon: "calendar",
                label: "Calendar"
            )

            tabButton(
                tab: .progress,
                icon: "chart.bar.fill",
                label: "Progress"
            )

            tabButton(
                tab: .profile,
                icon: "person.crop.circle.fill",
                label: "Profile"
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.black)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func tabButton(
        tab: MainTabView.Tab,
        icon: String,
        label: String
    ) -> some View {

        Button {

            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }

        } label: {

            Image(systemName: icon)
                .font(
                    .system(
                        size: 21,
                        weight: selectedTab == tab
                            ? .semibold
                            : .regular
                    )
                )
                .foregroundStyle(
                    selectedTab == tab
                        ? .white
                        : .white.opacity(0.45)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background {

                    if selectedTab == tab {

                        RoundedRectangle(
                            cornerRadius: 12
                        )
                        .fill(
                            .red.opacity(0.18)
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(
            selectedTab == tab
                ? .isSelected
                : []
        )
    }
}
