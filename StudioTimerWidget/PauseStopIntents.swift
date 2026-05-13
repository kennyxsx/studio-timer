// StudioTimerWidget/PauseStopIntents.swift
import AppIntents
import Foundation

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause / Resume Timer"
    static var description = IntentDescription("Toggles the Studio timer pause state.")

    func perform() async throws -> some IntentResult & OpensIntent {
        // Returning `opensIntent: OpenURLIntent(...)` instructs the system
        // to open the URL on the user's behalf. Safe to call from an extension
        // process; the system bridges into the host app via Scene .onOpenURL.
        .result(opensIntent: OpenURLIntent(URL(string: "studio-timer://command/toggle-pause")!))
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stops the Studio timer and creates a draft entry.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "studio-timer://command/stop")!))
    }
}
