// StudioTimer/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        if !appState.isAuthenticated {
            LoginView()
        } else if appState.selectedWorkspaceID == nil {
            WorkspacePickerView()
        } else {
            RootTabView(api: api, network: network)
        }
    }
}
