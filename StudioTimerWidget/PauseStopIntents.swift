// StudioTimerWidget/PauseStopIntents.swift
import AppIntents
import ActivityKit
import Foundation

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause / Resume Timer"
    static var description = IntentDescription("Toggles the Studio timer pause state.")

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<TimerAttributes>.activities.first else {
            return .result()
        }
        let current = activity.content.state
        let now = Date()
        let newState: TimerAttributes.TimerContentState

        if current.isPaused {
            // Resume — shift anchor forward by the pause duration so the
            // .timer Text in the widget keeps counting accurately.
            let pauseDuration = now.timeIntervalSince(current.pausedAt ?? now)
            newState = TimerAttributes.TimerContentState(
                startedAt: current.startedAt.addingTimeInterval(pauseDuration),
                pausedAt: nil,
                pausedElapsedSeconds: 0,
                isPaused: false)
        } else {
            // Pause — freeze elapsed seconds and record when pause began.
            let elapsed = max(Int(now.timeIntervalSince(current.startedAt)), 0)
            newState = TimerAttributes.TimerContentState(
                startedAt: current.startedAt,
                pausedAt: now,
                pausedElapsedSeconds: elapsed,
                isPaused: true)
        }
        await activity.update(ActivityContent(state: newState, staleDate: nil))
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stops the Studio timer and creates a draft entry.")

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<TimerAttributes>.activities.first else {
            return .result()
        }
        // End the activity. The app detects this on next foreground
        // (no active LA + non-idle TimerStore) and finalises the draft
        // via the existing TimerStore.stop() path.
        await activity.end(nil, dismissalPolicy: .immediate)
        return .result()
    }
}
