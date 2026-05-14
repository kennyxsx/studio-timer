// StudioTimer/StudioTimerApp.swift
import SwiftUI
import ActivityKit

@main
struct StudioTimerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var network = NetworkMonitor.shared
    /// Drain-side queue: shares the same on-disk file as TimerStore's own OutboundQueue.
    /// Both operate on `Application Support/outbound_queue.json`, so writes from
    /// TimerStore are visible to drain calls here on next reachability change.
    @StateObject private var queue = OutboundQueue()
    @StateObject private var timerStore: TimerStore
    @StateObject private var router = AppRouter()

    @Environment(\.scenePhase) private var scenePhase

    private let api = APIClient(baseURL: AppState.apiBaseURL)

    init() {
        let api = APIClient(baseURL: AppState.apiBaseURL)
        _timerStore = StateObject(wrappedValue: TimerStore(
            api: api,
            workspaceProvider: { UserDefaults.standard.string(forKey: "selected_workspace_id") },
            // Reads from the same singleton instance the App's @StateObject
            // holds — both paths see the same NWPathMonitor and the same
            // current isOnline value.
            isOnlineProvider: { MainActor.assumeIsolated { NetworkMonitor.shared.isOnline } }))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(network)
                .environmentObject(timerStore)
                .environmentObject(router)
                .environment(\.apiClient, api)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in handleCommand(url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await reconcileLiveActivity() }
                    }
                }
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

    @MainActor
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
            default:
                break
            }
        }
    }

    @MainActor
    private func reconcileLiveActivity() async {
        let activities = Activity<TimerAttributes>.activities

        if let activity = activities.first {
            let s = activity.content.state
            if s.isPaused, let pausedAt = s.pausedAt, timerStore.state == .running {
                await timerStore.applyExternalPause(at: pausedAt)
            } else if !s.isPaused, timerStore.state == .paused {
                await timerStore.applyExternalResume()
            }
        } else if timerStore.state != .idle, timerStore.active != nil {
            // No active LA but app thinks there's a running timer — user stopped from LA.
            // Stop the timer normally; this creates the draft entry.
            _ = try? await timerStore.stop()
        }
    }
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
