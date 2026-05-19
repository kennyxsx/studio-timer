// StudioTimer/Views/DraftsListView.swift
import SwiftUI

struct DraftsListView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var store: TimerStore
    @EnvironmentObject private var appState: AppState

    @State private var classifying: Entry?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if store.drafts.isEmpty {
                    ContentUnavailableView(
                        "No drafts",
                        systemImage: "tray",
                        description: Text("Stop a timer to capture time for later classification."))
                } else {
                    ForEach(store.drafts) { entry in
                        Button {
                            classifying = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                                Text("\(entry.durationMinutes) min · Tap to classify")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await delete(entry) }
                            } label: {
                                Label("Discard", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.base100)
            .navigationTitle("Drafts")
            .refreshable { await store.refreshDrafts() }
            .task { await store.refreshDrafts() }
            .sheet(item: $classifying) { entry in
                ClassifyView(entry: entry, mode: .classifyDraft)
            }
            .alert("Error", isPresented: .init(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func delete(_ entry: Entry) async {
        do {
            try await api.deleteEntry(entry.id)
            store.removeDraft(id: entry.id)
        } catch let APIError.http(_, _, message) {
            errorText = message
        } catch {
            // Cancellation errors are not user-facing — skip surfacing them.
            if !isCancellation(error) {
                errorText = error.localizedDescription
            }
        }
    }
}
