// StudioTimer/Views/ManualEntryFormView.swift
import SwiftUI

/// Sheet that gathers the when + how-long for a manually-created time entry
/// (i.e. not started via the timer). Calls /api/mobile/time/entries to create
/// the entry in DRAFT status; the parent (HistoryView) then presents
/// ClassifyView so the operator can attribute the entry before it lands in
/// history.
///
/// Splitting the date/duration step from the classification step matches the
/// existing draft-then-classify flow used after a real timer run — same
/// backend endpoints, same ClassifyView, no special "create classified
/// directly" code path required.
struct ManualEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState

    /// Called with the created draft Entry once the API round-trip succeeds.
    /// The parent should present ClassifyView for this entry.
    let onCreated: (Entry) -> Void

    @State private var startedAt = Date()
    @State private var durationMinutes: Int = 30
    @State private var isSaving: Bool = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Start", selection: $startedAt)
                        .datePickerStyle(.compact)
                }

                Section("Duration") {
                    Stepper(value: $durationMinutes, in: 1...1440, step: 5) {
                        Text("\(durationMinutes) min")
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.base100)
            .navigationTitle("Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Next") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let wsID = appState.selectedWorkspaceID else {
            errorText = "No workspace selected."
            return
        }
        isSaving = true
        defer { isSaving = false }
        errorText = nil
        do {
            let entry = try await api.createDraft(
                workspaceID: wsID,
                startedAt: startedAt,
                durationMinutes: durationMinutes)
            // Parent observes the created entry and pivots to ClassifyView.
            onCreated(entry)
            dismiss()
        } catch let APIError.http(_, _, message) {
            errorText = message
        } catch {
            if !isCancellation(error) {
                errorText = error.localizedDescription
            }
        }
    }
}
