// StudioTimer/Services/TimerStore.swift
import Foundation
import Combine

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var active: ActiveTimer?
    @Published private(set) var drafts: [Entry] = []
    @Published private(set) var isStopping: Bool = false

    private let api: APIClient
    private let workspaceProvider: () -> String?
    private let persistenceURL: URL
    private let activityController: LiveActivityController

    init(api: APIClient,
         workspaceProvider: @escaping () -> String?,
         activityController: LiveActivityController = .init()) {
        self.api = api
        self.workspaceProvider = workspaceProvider
        self.activityController = activityController
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)) ?? FileManager.default.temporaryDirectory
        self.persistenceURL = dir.appendingPathComponent("active_timer.json")
        loadFromDisk()
    }

    // MARK: - Actions

    func start() async {
        guard state == .idle else { return }
        let timer = ActiveTimer(startedAt: Date(), pauseIntervals: [], currentPauseStart: nil)
        active = timer
        state = .running
        persist()
        await activityController.start(for: timer)
    }

    func pause() async {
        guard state == .running, var t = active else { return }
        t.currentPauseStart = Date()
        active = t
        state = .paused
        persist()
        await activityController.update(for: t, isPaused: true)
    }

    func resume() async {
        guard state == .paused, var t = active, let pStart = t.currentPauseStart else { return }
        t.pauseIntervals.append(.init(start: pStart, end: Date()))
        t.currentPauseStart = nil
        active = t
        state = .running
        persist()
        await activityController.update(for: t, isPaused: false)
    }

    @discardableResult
    func stop() async throws -> Entry? {
        guard let t = active else { return nil }
        guard let wsID = workspaceProvider() else {
            throw APIError.http(status: 400, code: "NO_WORKSPACE", message: "No workspace selected")
        }
        isStopping = true
        defer { isStopping = false }

        // Resolve any active pause to a closed interval before computing duration.
        var resolved = t
        if let pStart = resolved.currentPauseStart {
            resolved.pauseIntervals.append(.init(start: pStart, end: Date()))
            resolved.currentPauseStart = nil
        }
        let seconds = resolved.elapsedSeconds(at: Date())
        let minutes = max(seconds / 60, 1)

        // Post draft to backend.
        let entry = try await api.createDraft(
            workspaceID: wsID,
            startedAt: resolved.startedAt,
            durationMinutes: minutes)

        // Append to local drafts, clear active state.
        drafts.insert(entry, at: 0)
        active = nil
        state = .idle
        clearPersistence()
        await activityController.end()
        return entry
    }

    func discardActive() {
        active = nil
        state = .idle
        clearPersistence()
        Task { await activityController.end() }
    }

    // MARK: - Drafts management

    func refreshDrafts() async {
        guard let wsID = workspaceProvider() else { return }
        do {
            let entries = try await api.listEntries(
                workspaceID: wsID,
                from: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                to: Date(),
                status: .draft)
            drafts = entries
        } catch {
            // Best-effort; surface errors via View-level state if needed.
        }
    }

    func removeDraft(id: String) {
        drafts.removeAll { $0.id == id }
    }

    func updateDraft(_ updated: Entry) {
        if updated.status == .draft {
            if let idx = drafts.firstIndex(where: { $0.id == updated.id }) {
                drafts[idx] = updated
            } else {
                drafts.insert(updated, at: 0)
            }
        } else {
            drafts.removeAll { $0.id == updated.id }
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let t = active else { clearPersistence(); return }
        do {
            let data = try JSONEncoder().encode(t)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // Best-effort; log if a logger exists.
        }
    }

    private func clearPersistence() {
        try? FileManager.default.removeItem(at: persistenceURL)
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let restored = try JSONDecoder().decode(ActiveTimer.self, from: data)
            self.active = restored
            self.state = restored.currentPauseStart != nil ? .paused : .running
            Task { await activityController.start(for: restored) }
        } catch {
            try? FileManager.default.removeItem(at: persistenceURL)
        }
    }
}
