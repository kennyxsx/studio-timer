// StudioTimer/Services/LiveActivityController.swift
import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    private var activity: Activity<TimerAttributes>?

    private func pauseAdjustedAnchor(for timer: ActiveTimer) -> Date {
        let pausedSum = timer.pauseIntervals.reduce(0) { $0 + $1.duration }
        return timer.startedAt.addingTimeInterval(pausedSum)
    }

    func start(for timer: ActiveTimer) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let isPaused = timer.currentPauseStart != nil
        let state = TimerAttributes.TimerContentState(
            startedAt: pauseAdjustedAnchor(for: timer),
            pausedAt: isPaused ? timer.currentPauseStart : nil,
            pausedElapsedSeconds: timer.elapsedSeconds(at: Date()),
            isPaused: isPaused)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            activity = try Activity<TimerAttributes>.request(
                attributes: TimerAttributes(),
                content: content,
                pushType: nil)
        } catch {
            activity = nil
        }
    }

    /// Called from `TimerStore.loadFromDisk()` when the app restarts and finds
    /// a persisted active timer. Reattaches to any system-managed Live Activity
    /// from before the force-quit instead of spawning a duplicate. If there are
    /// multiple stray activities (e.g. from earlier launches that hit this
    /// duplicate bug), ends the extras and keeps one.
    func reattachOrStart(for timer: ActiveTimer) async {
        let existing = Activity<TimerAttributes>.activities
        if let primary = existing.first {
            // Reattach: hand the reference to the controller and sync state.
            activity = primary
            // End any orphans beyond the primary so we don't accumulate them.
            for orphan in existing.dropFirst() {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
            await update(for: timer, isPaused: timer.currentPauseStart != nil)
            return
        }
        // No existing activity (e.g., user dismissed it, or iOS auto-ended after 12h).
        // Start fresh.
        await start(for: timer)
    }

    func update(for timer: ActiveTimer, isPaused: Bool) async {
        guard let activity else { return }
        let state = TimerAttributes.TimerContentState(
            startedAt: pauseAdjustedAnchor(for: timer),
            pausedAt: isPaused ? (timer.currentPauseStart ?? Date()) : nil,
            pausedElapsedSeconds: timer.elapsedSeconds(at: Date()),
            isPaused: isPaused)
        await activity.update(.init(state: state, staleDate: nil))
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
