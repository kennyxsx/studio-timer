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
        let state = TimerAttributes.TimerContentState(
            startedAt: pauseAdjustedAnchor(for: timer),
            pausedElapsedSeconds: timer.elapsedSeconds(at: Date()),
            isPaused: timer.currentPauseStart != nil)
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

    func update(for timer: ActiveTimer, isPaused: Bool) async {
        guard let activity else { return }
        let state = TimerAttributes.TimerContentState(
            startedAt: pauseAdjustedAnchor(for: timer),
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
