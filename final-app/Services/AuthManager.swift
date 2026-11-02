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

    // Emails a Firebase password reset link and returns a message to show.
    func sendPasswordReset() async -> String {
        guard let email = userEmail else { return "This account has no email address." }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return "We've emailed a password reset link to \(email)."
        } catch {
            return friendlyMessage(for: error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Account deletion (App Store Guideline 5.1.1(v))

    // Firebase only deletes an account after a recent sign-in, so the password
    // is checked first. Returns an error message, or nil on success.
    func reauthenticate(password: String) async -> String? {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            return "You need to be signed in to delete your account."
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            return nil
        } catch {
            return friendlyMessage(for: error)
        }
    }

    // Deletes the Firebase account itself and the details saved on this device.
    // isSignedIn flips via the state listener, which returns to the sign-in screen.
    func deleteCurrentUser() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        let uid = user.uid
        do {
            try await user.delete()
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: UserPreferences.displayNameKey(for: uid))
            let onboarded = defaults.string(forKey: UserPreferences.onboardedUserIDsKey) ?? ""
            defaults.set(UserPreferences.removing(uid, from: onboarded), forKey: UserPreferences.onboardedUserIDsKey)
            return nil
        } catch {
            return friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .userNotFound:
            return "No account exists with that email. Choose Create Account to sign up."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .invalidCredential:
            // With Firebase's email enumeration protection on (the default), a
            // missing account and a wrong password return this same error.
            return "Incorrect email or password, or no account exists with that email. New here? Choose Create Account."
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
