// StudioTimer/Shared/TimerAttributes.swift
import Foundation
import ActivityKit

struct TimerAttributes: ActivityAttributes {
    public typealias ContentState = TimerContentState

    struct TimerContentState: Codable, Hashable {
        var startedAt: Date          // pause-adjusted anchor
        var pausedAt: Date?          // nil if running; non-nil if paused (wall-clock time of pause)
        var pausedElapsedSeconds: Int // frozen elapsed for display when paused
        var isPaused: Bool           // explicit flag for widget rendering decisions
    }
}
