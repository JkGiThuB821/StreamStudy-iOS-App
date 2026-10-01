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
    @State private var socialSignInNote: String?

    enum Mode { case signIn, signUp }

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 6
        let nameOK = mode == .signIn || !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOK && passwordOK && nameOK
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("StreamStudy")
                        .font(.spaceGrotesk(size: 22, weight: .bold))
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR LEARNING. YOUR SCHEDULE.")
                            .font(.sgCaption)
                            .foregroundStyle(.secondary)
                        Text(mode == .signIn ? "Welcome back" : "Start learning today")
                            .font(.spaceGrotesk(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Picker("Mode", selection: $mode) {
                        Text("Sign In").tag(Mode.signIn)
                        Text("Create Account").tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { authManager.errorMessage = nil }

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            TextField("Full name", text: $fullName)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Email address", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.sgCaption)
                            .foregroundStyle(.red)
                    }

                    Button(action: submit) {
                        ZStack {
                            Text(mode == .signIn ? "Sign In" : "Create Account")
                                .opacity(authManager.isLoading ? 0 : 1)
                            if authManager.isLoading {
                                ProgressView().tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? .red : .red.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!isFormValid || authManager.isLoading)

                    HStack { Divider(); Text("OR").foregroundStyle(.secondary).font(.sgCaption); Divider() }

                    Button(action: { socialSignInNote = "Sign in with Apple isn't wired up yet." }) {
                        Label("Continue with Apple", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: { socialSignInNote = "Google sign-in isn't wired up yet." }) {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let socialSignInNote {
                        Text(socialSignInNote)
                            .font(.sgCaption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                        .font(.sgCaption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(24)
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
