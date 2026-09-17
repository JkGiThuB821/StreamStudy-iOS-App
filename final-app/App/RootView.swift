//
//  RootView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//

import SwiftUI

struct RootView: View {
    @State private var isSignedIn = false
    
    var body: some View {
        Group {
            if isSignedIn {
                MainTabView(isSignedIn: $isSignedIn)
            } else {
                SignInView(isSignedIn: $isSignedIn)
            }
        }
        .preferredColorScheme(.dark)
    }
}
