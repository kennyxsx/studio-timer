// StudioTimer/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: TimerStore

    @State private var entries: [Entry] = []
    @State private var rangeDays: Int = 30
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @State private var editing: Entry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $rangeDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                }
                ForEach(entries) { entry in
                    Button { editing = entry } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                                Spacer()
                                Text("\(entry.durationMinutes) min")
                                    .foregroundStyle(.secondary)
                            }
                            Text(summary(for: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await delete(entry) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("History")
            .refreshable { await reload() }
            .task(id: rangeDays) { await reload() }
            .sheet(item: $editing, onDismiss: { Task { await reload() } }) { entry in
                ClassifyView(entry: entry, mode: .editClassified)
            }
            .alert("Error", isPresented: .init(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func reload() async {
        guard let wsID = appState.selectedWorkspaceID else { return }
        isLoading = true
        defer { isLoading = false }
        let from = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
        do {
            entries = try await api.listEntries(workspaceID: wsID, from: from, to: Date(), status: nil)
        } catch let APIError.http(_, _, message) {
            errorText = message
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(_ entry: Entry) async {
        do {
            try await api.deleteEntry(entry.id)
            entries.removeAll { $0.id == entry.id }
            // If the entry is also in the drafts list (was draft), drop it there too.
            store.removeDraft(id: entry.id)
        } catch let APIError.http(_, _, message) {
            errorText = message
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func summary(for entry: Entry) -> String {
        if entry.status == .draft { return "Draft — not yet classified" }
        if !entry.splits.isEmpty { return "Project (split across \(entry.splits.count))" }
        if entry.customerUserID != nil { return "Customer overhead" }
        if let cat = entry.category, !cat.isEmpty { return "Internal: \(cat)" }
        return "Classified"
    }
}
