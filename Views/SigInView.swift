//
//  SigInView.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 17/9/2026.
//

import SwiftUI

struct SignInView: View {
    @Binding var isSignedIn: Bool
    
    @State private var mode: Mode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    
    enum Mode { case signIn, signUp }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                Text("STUDYFLIX")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR LEARNING. YOUR SCHEDULE.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(mode == .signIn ? "Welcome back" : "Start Learning today")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Create Account").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                
                VStack(spacing: 12) {
                    if mode == .signUp {
                        TextField("Full Name", text: $fullName)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("Email Address", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: { isSignedIn = true }) {
                    Text(mode == .signIn ? "Sign In": "Create Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                HStack{ Divider(); Text("OR").foregroundStyle(.secondary).font(.caption); Divider() }
                
                Button(action: { isSignedIn = true }) {
                    Label("Continue with Apple", systemImage: "apple.logo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: { isSignedIn = true }) {
                    Label("Continue with Google", systemImage: "g.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Spacer()
                
                Text("By continuing you agree to our Terms of Use and Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
            }
            .padding(24)
        }
    }
}

#Preview {
    SignInView(isSignedIn: .constant(false))
}
