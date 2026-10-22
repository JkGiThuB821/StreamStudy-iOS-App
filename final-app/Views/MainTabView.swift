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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var topics: [Topic]
    @Query private var deadlines: [Deadline]
    @Query private var digests: [WeeklyDigest]
    @Query private var progressEntries: [StudyProgress]
    @AppStorage(NotificationService.weeklyDigestEnabledKey) private var weeklyDigestEnabled = true

    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()

    @ObservedObject private var notifications = NotificationService.shared
    @AppStorage(NotificationService.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(NotificationService.reminderLeadDaysKey) private var reminderLeadDays = 1

    // Changes whenever a deadline, a reminder preference or the permission changes, so reminders get rescheduled.
    private var reminderSignature: [String] {
        ["\(remindersEnabled)-\(reminderLeadDays)-\(notifications.authorizationStatus.rawValue)"]
            + deadlines.map { "\($0.id)-\($0.title)-\($0.dueDate.timeIntervalSince1970)" }
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
        .task(id: reminderSignature) {
            // Only prompts the first time; afterwards it returns the saved choice immediately.
            await NotificationService.shared.requestPermission()
            await NotificationService.shared.scheduleNotifications(for: deadlines)
        }
        // Season Pass: make sure this week's drop exists (also re-checked when topics
        // change, e.g. after sign-in sync), then catch up on AI tagging in the background.
        .task(id: topics.count) {
            refreshWeeklyDigest()
            await ResourceTaggingService.backfill(topics: topics)
        }
        .task(id: "\(weeklyDigestEnabled)-\(notifications.authorizationStatus.rawValue)") {
            await NotificationService.shared.scheduleWeeklyDigest()
        }
        .onChange(of: scenePhase) { _, phase in
            // A new week may have started while the app was in the background.
            if phase == .active { refreshWeeklyDigest() }
        }
        .onAppear {
            route(deepLinkRouter.destination)
        }
        .onChange(of: deepLinkRouter.destination) { _, destination in
            route(destination)
        }
    }

    // MARK: Season Pass

    private func refreshWeeklyDigest() {
        WeeklyDigestService.generateIfNeeded(
            topics: topics,
            existing: digests,
            progress: progressEntries,
            context: modelContext
        )
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
        case .digest:
            // HomeView opens the digest sheet and clears the destination itself.
            selectedTab = .home
            homePath = NavigationPath()
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
        // Icons grow with Dynamic Type, capped so five tabs still fit across the screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.cardStroke)
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
                .font(.title3)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundStyle(
                    selectedTab == tab
                        ? Color.primary
                        : Color.secondary
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
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
