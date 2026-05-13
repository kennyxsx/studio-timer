// StudioTimer/StudioTimerApp.swift
import SwiftUI

@main
struct StudioTimerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var network = NetworkMonitor()
    /// Drain-side queue: shares the same on-disk file as TimerStore's own OutboundQueue.
    /// Both operate on `Application Support/outbound_queue.json`, so writes from
    /// TimerStore are visible to drain calls here on next reachability change.
    @StateObject private var queue = OutboundQueue()
    @StateObject private var timerStore: TimerStore

    private let api = APIClient(baseURL: AppState.apiBaseURL)

    init() {
        let api = APIClient(baseURL: AppState.apiBaseURL)
        _timerStore = StateObject(wrappedValue: TimerStore(
            api: api,
            workspaceProvider: { UserDefaults.standard.string(forKey: "selected_workspace_id") },
            isOnlineProvider: { true }))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(network)
                .environmentObject(timerStore)
                .environment(\.apiClient, api)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in handleCommand(url) }
                .onChange(of: network.isOnline) { _, online in
                    if online {
                        Task { await queue.drain(using: api) }
                    }
                }
                .task {
                    if network.isOnline {
                        await queue.drain(using: api)
                    }
                }
        }
    }

    private func handleCommand(_ url: URL) {
        guard url.scheme == "studio-timer", url.host == "command" else { return }
        let command = url.lastPathComponent
        Task { @MainActor in
            switch command {
            case "toggle-pause":
                if timerStore.state == .running {
                    await timerStore.pause()
                } else if timerStore.state == .paused {
                    await timerStore.resume()
                }
            case "stop":
                _ = try? await timerStore.stop()
            default: break
            }
        }
    }
}

extension Notification.Name {
    static let studioTimerCommand = Notification.Name("studioTimerCommand")
}

extension AppState {
    nonisolated static var apiBaseURL: URL {
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
