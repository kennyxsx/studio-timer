// StudioTimer/Services/LiveActivityController.swift
import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    private var activity: Activity<TimerAttributes>?

    func start(for timer: ActiveTimer) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TimerAttributes.TimerContentState(
            startedAt: timer.startedAt,
            pausedElapsedSeconds: 0,
            isPaused: false)
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
        let pausedElapsed = timer.elapsedSeconds(at: Date())
        let state = TimerAttributes.TimerContentState(
            startedAt: timer.startedAt,
            pausedElapsedSeconds: pausedElapsed,
            isPaused: isPaused)
        await activity.update(.init(state: state, staleDate: nil))
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
