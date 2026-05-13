// StudioTimerWidget/StudioTimerWidgetBundle.swift
import WidgetKit
import SwiftUI

@main
struct StudioTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmptyWidget()
    }
}

// Placeholder so the bundle compiles even when there are no real widgets yet.
struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmptyWidget", provider: EmptyProvider()) { _ in
            Text("")
        }
        .configurationDisplayName("Empty")
        .description("Placeholder")
        .supportedFamilies([.systemSmall])
    }
}

private struct EmptyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmptyEntry { EmptyEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (EmptyEntry) -> Void) {
        completion(EmptyEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EmptyEntry>) -> Void) {
        completion(Timeline(entries: [EmptyEntry(date: .now)], policy: .never))
    }
}

private struct EmptyEntry: TimelineEntry { let date: Date }
