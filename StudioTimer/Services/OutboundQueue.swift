// StudioTimer/Services/OutboundQueue.swift
import Foundation

struct OutboundCommand: Codable, Equatable {
    enum Kind: String, Codable { case stop }
    let kind: Kind
    let workspaceID: String
    let startedAt: Date
    let durationMinutes: Int

    static func stop(workspaceID: String, startedAt: Date, durationMinutes: Int) -> OutboundCommand {
        OutboundCommand(kind: .stop, workspaceID: workspaceID, startedAt: startedAt, durationMinutes: durationMinutes)
    }
}

@MainActor
final class OutboundQueue: ObservableObject {
    @Published private(set) var pending: [OutboundCommand] = []

    private let persistenceURL: URL
    private let maxSize: Int = 10

    init(persistenceURL: URL = OutboundQueue.defaultURL) {
        self.persistenceURL = persistenceURL
        load()
    }

    func enqueue(_ command: OutboundCommand) throws {
        pending.append(command)
        if pending.count > maxSize {
            pending.removeFirst(pending.count - maxSize)
        }
        try persist()
    }

    func drain(using api: APIClient) async {
        // Refresh from disk: another instance of OutboundQueue (e.g., the one
        // inside TimerStore) may have written commands we haven't observed.
        load()
        var remaining: [OutboundCommand] = []
        for cmd in pending {
            switch cmd.kind {
            case .stop:
                do {
                    _ = try await api.createDraft(
                        workspaceID: cmd.workspaceID,
                        startedAt: cmd.startedAt,
                        durationMinutes: cmd.durationMinutes)
                } catch {
                    remaining.append(cmd)
                }
            }
        }
        pending = remaining
        try? persist()
    }

    // MARK: - Persistence

    private func persist() throws {
        let data = try JSONEncoder().encode(pending)
        try data.write(to: persistenceURL, options: .atomic)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            pending = try JSONDecoder().decode([OutboundCommand].self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: persistenceURL)
            pending = []
        }
    }

    nonisolated static var defaultURL: URL {
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)) ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("outbound_queue.json")
    }
}
