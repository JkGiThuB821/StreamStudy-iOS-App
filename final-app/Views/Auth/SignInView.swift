//
//  SigInView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var mode: Mode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""

    enum Mode { case signIn, signUp }

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 6
        let nameOK = mode == .signIn || !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOK && passwordOK && nameOK
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("StreamStudy")
                        .font(.spaceGrotesk(size: 26, weight: .bold, relativeTo: .title))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 6) {
                        Text("YOUR LEARNING. YOUR SCHEDULE.")
                            .font(.spaceGrotesk(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                        Text(mode == .signIn ? "Welcome back" : "Start learning today")
                            .font(.spaceGrotesk(size: 30, weight: .bold, relativeTo: .largeTitle))
                            .foregroundStyle(.primary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                    // The form card, as in the mock-up.
                    VStack(spacing: 14) {
                        PillPicker(selection: $mode, options: [(.signIn, "Sign In"), (.signUp, "Create Account")])
                            .onChange(of: mode) { authManager.errorMessage = nil }

                        if mode == .signUp {
                            TextField("Full name", text: $fullName)
                                .characterLimit($fullName, TextLimits.name)
                                .textContentType(.name)
                                .inputFieldStyle()
                        }
                        TextField("Email address", text: $email)
                            .characterLimit($email, TextLimits.email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .inputFieldStyle()
                        SecureField("Password", text: $password)
                            .characterLimit($password, TextLimits.password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .inputFieldStyle()

                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .font(.sgCaption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            ZStack {
                                Text(mode == .signIn ? "Sign In" : "Create Account")
                                    .opacity(authManager.isLoading ? 0 : 1)
                                if authManager.isLoading {
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || authManager.isLoading)
                    }
                    .padding(18)
                    .cardStyle(cornerRadius: 16)

                    Text("By continuing, you agree to our Terms of Use and Privacy Policy.")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                // Keeps the form a readable width in landscape and on iPad.
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn:
                await authManager.signIn(email: email, password: password)
            case .signUp:
                await authManager.signUp(fullName: fullName, email: email, password: password)
            }
        }
    }
}
