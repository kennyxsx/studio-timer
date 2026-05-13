// StudioTimer/Views/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    let api: APIClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var timerStore: TimerStore

    init(api: APIClient) {
        self.api = api
        // Initialize TimerStore once for the lifetime of the authenticated session,
        // using the shared APIClient (so 401-refresh and keychain reads/writes
        // remain coherent with the rest of the app).
        _timerStore = StateObject(wrappedValue: TimerStore(
            api: api,
            workspaceProvider: { UserDefaults.standard.string(forKey: "selected_workspace_id") }))
    }

    var body: some View {
        TabView {
            TimerView()
                .environmentObject(timerStore)
                .tabItem { Label("Timer", systemImage: "timer") }
            DraftsListView()
                .environmentObject(timerStore)
                .tabItem { Label("Drafts", systemImage: "tray.full") }
            HistoryView()
                .environmentObject(timerStore)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}
