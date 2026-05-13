// StudioTimer/Views/TimerView.swift
import SwiftUI

struct TimerView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: TimerStore

    @State private var showingSettings = false
    @State private var classifyDraft: Entry?
    @State private var errorText: String?
    @State private var stopConfirmationActive: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                elapsedDisplay

                controls

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Studio Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $classifyDraft) { draft in
                ClassifyView(entry: draft, mode: .classifyDraft)
            }
            .onReceive(NotificationCenter.default.publisher(for: .studioTimerCommand)) { note in
                guard let cmd = note.object as? String else { return }
                Task {
                    switch cmd {
                    case "toggle-pause":
                        if store.state == .running { await store.pause() }
                        else if store.state == .paused { await store.resume() }
                    case "stop":
                        await self.stop()
                    default: break
                    }
                }
            }
            .confirmationDialog(
                "Timer ran for \(timerString(seconds: store.active?.elapsedSeconds(at: Date()) ?? 0))",
                isPresented: $stopConfirmationActive,
                titleVisibility: .visible)
            {
                Button("Save anyway") { Task { await performStop() } }
                Button("Discard timer", role: .destructive) { store.discardActive() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is unusually long. Did you forget to stop it?")
            }
        }
    }

    @ViewBuilder
    private var elapsedDisplay: some View {
        if let active = store.active {
            if store.state == .paused {
                Text(timerString(seconds: active.elapsedSeconds(at: Date())))
                    .font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                // Anchor: startedAt shifted forward by the sum of past pause intervals,
                // so SwiftUI's `.timer` style counts up from "first started" minus pauses.
                // Without this shift, the display would count from the original startedAt
                // and visibly drift past the real elapsed time after any pause.
                let pausedSum = active.pauseIntervals.reduce(0) { $0 + $1.duration }
                let anchor = active.startedAt.addingTimeInterval(pausedSum)
                Text(anchor, style: .timer)
                    .font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit())
            }
        } else {
            Text("00:00")
                .font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 24) {
            switch store.state {
            case .idle:
                Button { Task { await store.start() } } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            case .running:
                Button { Task { await store.pause() } } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button { Task { await stop() } } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            case .paused:
                Button { Task { await store.resume() } } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { Task { await stop() } } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.horizontal)
        .disabled(store.isStopping)
    }

    private func stop() async {
        guard let active = store.active else { return }
        let runtime = active.elapsedSeconds(at: Date())
        if runtime > 24 * 3600 {
            stopConfirmationActive = true
            return
        }
        await performStop()
    }

    private func performStop() async {
        errorText = nil
        do {
            if let entry = try await store.stop() {
                classifyDraft = entry
            }
        } catch let APIError.http(_, _, message) {
            errorText = message
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func timerString(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

}
