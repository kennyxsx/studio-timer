// StudioTimer/Models/ActiveTimer.swift
import Foundation

struct ActiveTimer: Codable, Equatable {
    let startedAt: Date
    var pauseIntervals: [PauseInterval]
    var currentPauseStart: Date?

    struct PauseInterval: Codable, Equatable {
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Computes effective elapsed seconds at the given moment, subtracting:
    /// - the sum of closed pause intervals
    /// - the duration of the current pause (if paused)
    func elapsedSeconds(at now: Date) -> Int {
        let total = now.timeIntervalSince(startedAt)
        let closedPausedSum = pauseIntervals.reduce(0) { $0 + $1.duration }
        let activePauseDuration = currentPauseStart.map { now.timeIntervalSince($0) } ?? 0
        let effective = total - closedPausedSum - activePauseDuration
        return max(Int(effective), 0)
    }
}
