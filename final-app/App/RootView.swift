//
//  RootView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isSignedIn {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .font(.sgBody)
        .preferredColorScheme(.dark)
        .animation(.default, value: authManager.isSignedIn)
    }
}
