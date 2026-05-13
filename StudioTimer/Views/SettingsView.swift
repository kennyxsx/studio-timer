// StudioTimer/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState

    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Email", value: appState.currentUserEmail ?? "—")
                    LabeledContent("Name", value: appState.currentUserName ?? "—")
                }

                Section("Workspace") {
                    let current = appState.availableWorkspaces.first { $0.id == appState.selectedWorkspaceID }
                    LabeledContent("Active", value: current?.name ?? "—")
                    if appState.availableWorkspaces.count >= 2 {
                        Button("Switch workspace") {
                            appState.setWorkspace("")
                            appState.selectedWorkspaceID = nil
                            dismiss()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await signOut() }
                    } label: {
                        if isLoggingOut {
                            ProgressView()
                        } else {
                            Text("Sign Out")
                        }
                    }
                    .disabled(isLoggingOut)
                }

                Section("About") {
                    LabeledContent("Version",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func signOut() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        // Best-effort: tell the backend to revoke. If it fails, still clear locally.
        try? await api.logout()
        appState.logout()
        dismiss()
    }
}
