// StudioTimerWidget/StudioTimerLiveActivity.swift
import ActivityKit
import WidgetKit
import SwiftUI

struct StudioTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LockScreenView(state: context.state)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
            } compactTrailing: {
                if context.state.isPaused {
                    Text(formatted(seconds: context.state.pausedElapsedSeconds))
                        .monospacedDigit()
                } else {
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
            }
        }
    }

    private func formatted(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

private struct LockScreenView: View {
    let state: TimerAttributes.TimerContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: state.isPaused ? "pause.circle.fill" : "timer")
                Text(state.isPaused ? "Paused" : "Studio Timer")
                    .font(.headline)
                Spacer()
            }
            if state.isPaused {
                Text(formatted(seconds: state.pausedElapsedSeconds))
                    .font(.system(size: 40, weight: .light, design: .rounded).monospacedDigit())
            } else {
                Text(state.startedAt, style: .timer)
                    .font(.system(size: 40, weight: .light, design: .rounded).monospacedDigit())
            }
            HStack(spacing: 16) {
                Link(destination: URL(string: "studio-timer://command/toggle-pause")!) {
                    Label(state.isPaused ? "Resume" : "Pause", systemImage: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                }

                Link(destination: URL(string: "studio-timer://command/stop")!) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        }
    }

    private func formatted(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
