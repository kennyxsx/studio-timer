// StudioTimer/Views/LoginView.swift
import SwiftUI

struct LoginView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?

    private let keychain = KeychainStore()

    var body: some View {
        VStack(spacing: 24) {
            Text("Studio Timer")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: signIn) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign In").bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Spacer()
        }
        .padding(.top, 60)
    }

    private func signIn() {
        Task {
            isLoading = true
            errorText = nil
            defer { isLoading = false }
            do {
                let resp = try await api.login(email: email, password: password)
                try keychain.setAccessToken(resp.accessToken)
                try keychain.setRefreshToken(resp.refreshToken)
                appState.didLogIn(workspaces: resp.workspaces, user: resp.user)
            } catch let APIError.http(_, _, message) {
                errorText = message
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
