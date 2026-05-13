// StudioTimer/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if !appState.isAuthenticated {
            LoginView()
        } else if appState.selectedWorkspaceID == nil {
            WorkspacePickerView()
        } else {
            RootTabView()
        }
    }
}
