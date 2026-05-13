// StudioTimer/Views/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    let api: APIClient
    @EnvironmentObject private var appState: AppState
    @StateObject private var timerStore: TimerStore

    /// `network` is accepted as a parameter so that TimerStore can capture it in its
    /// `isOnlineProvider` closure at init time — `@EnvironmentObject` is not yet
    /// injected when `@StateObject` is initialized, so we pass the shared instance
    /// explicitly from the call site (RootView already holds it as an EnvironmentObject).
    init(api: APIClient, network: NetworkMonitor) {
        self.api = api
        _timerStore = StateObject(wrappedValue: TimerStore(
            api: api,
            workspaceProvider: { UserDefaults.standard.string(forKey: "selected_workspace_id") },
            isOnlineProvider: { network.isOnline }))
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
