// StudioTimer/Views/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
            DraftsListView()
                .tabItem { Label("Drafts", systemImage: "tray.full") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}
