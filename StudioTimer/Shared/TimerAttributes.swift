// StudioTimer/Shared/TimerAttributes.swift
import Foundation
import ActivityKit

struct TimerAttributes: ActivityAttributes {
    public typealias ContentState = TimerContentState

    struct TimerContentState: Codable, Hashable {
        var startedAt: Date
        var pausedElapsedSeconds: Int
        var isPaused: Bool
    }
}
