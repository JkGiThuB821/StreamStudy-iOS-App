//
//  MainTabView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//

import SwiftUI

struct MainTabView: View {

    enum Tab: Hashable {
        case home
        case subjects
        case calendar
        case progress
        case profile
    }

    @State private var selectedTab: Tab = .home

    var body: some View {

        TabView(selection: $selectedTab) {

            // MARK: Home

            NavigationStack {
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
