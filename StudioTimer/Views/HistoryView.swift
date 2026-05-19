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
    @State private var showingManualForm: Bool = false
    /// Set by ManualEntryFormView when its create-draft call succeeds.
    /// Stored separately from `pendingClassification` because SwiftUI can
    /// only present one sheet at a time — the manual form's sheet must
    /// fully dismiss before we can present ClassifyView. Promoted to
    /// `pendingClassification` in the manual-form sheet's onDismiss.
    @State private var stagedDraft: Entry?
    /// Set after stagedDraft is promoted in onDismiss. Drives the
    /// ClassifyView sheet so the operator classifies the new draft
    /// immediately rather than seeing an unclassified row in history.
    @State private var pendingClassification: Entry?

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
            .scrollContentBackground(.hidden)
            .background(Theme.base100)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingManualForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add manual entry")
                }
            }
            .refreshable { await reload() }
            .task(id: rangeDays) { await reload() }
            .sheet(item: $editing, onDismiss: { Task { await reload() } }) { entry in
                ClassifyView(entry: entry, mode: .editClassified)
            }
            .sheet(isPresented: $showingManualForm, onDismiss: {
                // Promote the staged draft now that the manual-form sheet has
                // fully dismissed — SwiftUI can only present one sheet at a
                // time, so this is the right moment to trigger ClassifyView.
                if let staged = stagedDraft {
                    stagedDraft = nil
                    pendingClassification = staged
                }
            }) {
                ManualEntryFormView { entry in
                    stagedDraft = entry
                }
            }
            .sheet(item: $pendingClassification, onDismiss: { Task { await reload() } }) { entry in
                ClassifyView(entry: entry, mode: .classifyDraft)
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
            // Ignore Task-cancellation errors fired by SwiftUI when the view's
            // .task is cancelled on tab switch — they're not user-facing.
            // Surfacing them produced an "Error: cancelled" popup loop.
            if !isCancellation(error) {
                errorText = error.localizedDescription
            }
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
            if !isCancellation(error) {
                errorText = error.localizedDescription
            }
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
