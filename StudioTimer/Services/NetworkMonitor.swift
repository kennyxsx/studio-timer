// StudioTimer/Services/NetworkMonitor.swift
import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    /// Shared singleton. Used both as the App's @StateObject (for view
    /// observation) and as the source of truth for non-view code like
    /// TimerStore's isOnlineProvider closure. Sharing one NWPathMonitor
    /// instance also avoids running two of them in parallel.
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "de.ivy-s.studiotimer.network")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
