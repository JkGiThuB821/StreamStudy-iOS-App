//
//  AuthManager.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 28/9/2026.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String?
    @Published var uid: String?
    @Published var displayName: String?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.isSignedIn = user != nil
            self.userEmail = user?.email
            self.uid = user?.uid
            // Prefer the name saved on this device (works offline), then the account's.
            self.displayName = user.flatMap {
                UserDefaults.standard.string(forKey: UserPreferences.displayNameKey(for: $0.uid)) ?? $0.displayName
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            // isSignedIn flips via the state listener above once this succeeds.
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signUp(fullName: String, email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            try await changeRequest.commitChanges()
            saveDisplayNameLocally(fullName, uid: result.user.uid)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // Saves the name on the device straight away, then updates the Firebase
    // profile. If that fails (e.g. offline) the local name is still used.
    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let user = Auth.auth().currentUser, !trimmed.isEmpty else { return }
        saveDisplayNameLocally(trimmed, uid: user.uid)

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = trimmed
        try? await changeRequest.commitChanges()
    }

    private func saveDisplayNameLocally(_ name: String, uid: String) {
        UserDefaults.standard.set(name, forKey: UserPreferences.displayNameKey(for: uid))
        displayName = name
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .emailAlreadyInUse:
            return "An account with that email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .invalidEmail:
            return "That email address doesn't look right."
        case .networkError:
            return "No internet connection. Please try again."
        default:
            return error.localizedDescription
        }
    }
}
