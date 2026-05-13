// StudioTimerWidget/PauseStopIntents.swift
import AppIntents
import ActivityKit
import Foundation
import os.log

private let intentLog = OSLog(subsystem: "de.ivy-s.studiotimer", category: "LiveActivityIntent")

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause / Resume Timer"
    static var description = IntentDescription("Toggles the Studio timer pause state.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        os_log("PauseTimerIntent.perform() invoked", log: intentLog, type: .info)

        let activities = Activity<TimerAttributes>.activities
        os_log("Activity count: %d", log: intentLog, type: .info, activities.count)

        guard let activity = activities.first else {
            os_log("No active activity found; returning early", log: intentLog, type: .error)
            return .result()
        }

        let current = activity.content.state
        let now = Date()
        let newTapCount = current.debugTapCount + 1
        let newState: TimerAttributes.TimerContentState

        if current.isPaused {
            // Resume — shift anchor forward by the pause duration so the
            // .timer Text in the widget keeps counting accurately.
            let pauseDuration = now.timeIntervalSince(current.pausedAt ?? now)
            newState = TimerAttributes.TimerContentState(
                startedAt: current.startedAt.addingTimeInterval(pauseDuration),
                pausedAt: nil,
                pausedElapsedSeconds: 0,
                isPaused: false,
                debugTapCount: newTapCount)
        } else {
            // Pause — freeze elapsed seconds and record when pause began.
            let elapsed = max(Int(now.timeIntervalSince(current.startedAt)), 0)
            newState = TimerAttributes.TimerContentState(
                startedAt: current.startedAt,
                pausedAt: now,
                pausedElapsedSeconds: elapsed,
                isPaused: true,
                debugTapCount: newTapCount)
        }
        await activity.update(ActivityContent(state: newState, staleDate: nil))
        os_log("Activity updated; new tap count: %d", log: intentLog, type: .info, newTapCount)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stops the Studio timer and creates a draft entry.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true   // Foreground the app so the classify sheet opens.

    func perform() async throws -> some IntentResult {
        os_log("StopTimerIntent.perform() invoked", log: intentLog, type: .info)

        let activities = Activity<TimerAttributes>.activities
        os_log("Activity count: %d", log: intentLog, type: .info, activities.count)

        guard let activity = activities.first else {
            os_log("No active activity found; returning early", log: intentLog, type: .error)
            return .result()
        }

        await activity.end(nil, dismissalPolicy: .immediate)
        os_log("Activity ended", log: intentLog, type: .info)
        return .result()
    }
}
