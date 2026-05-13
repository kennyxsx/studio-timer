// StudioTimer/StudioTimerApp.swift
import SwiftUI

@main
struct StudioTimerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(network)
                .environment(\.apiClient, APIClient(baseURL: AppState.apiBaseURL))
                .onOpenURL { url in handleCommand(url) }
        }
    }

    private func handleCommand(_ url: URL) {
        guard url.scheme == "studio-timer", url.host == "command" else { return }
        let command = url.lastPathComponent
        NotificationCenter.default.post(name: .studioTimerCommand, object: command)
    }
}

extension Notification.Name {
    static let studioTimerCommand = Notification.Name("studioTimerCommand")
}

extension AppState {
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["STUDIO_API_BASE_URL"] {
            return URL(string: override)!
        }
        if let str = Bundle.main.object(forInfoDictionaryKey: "StudioAPIBaseURL") as? String,
           let url = URL(string: str) {
            return url
        }
        return URL(string: "https://studio.ivy-s.de")!
    }
}

private struct APIClientKey: EnvironmentKey {
    static let defaultValue = APIClient(baseURL: AppState.apiBaseURL)
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
