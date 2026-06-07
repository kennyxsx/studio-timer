// StudioTimer/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: TimerStore
    @EnvironmentObject private var router: AppRouter

    @State private var entries: [Entry] = []
    @State private var rangeDays: Int = 30
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    /// Single source of truth for which sheet (if any) is presented. SwiftUI
    /// presents one sheet at a time, so one enum + one `.sheet(item:)` is more
    /// robust than stacking several `.sheet` modifiers on the same view.
    @State private var sheet: SheetRoute?
    /// Holds the draft created by ManualEntryFormView until its sheet has fully
    /// dismissed; promoted to a `.classifyDraft` route in `onDismiss` (the next
    /// sheet can't present until the current one is gone).
    @State private var draftAwaitingClassification: Entry?

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
                    Button { sheet = .editClassified(entry) } label: {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { router.closeTimer() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sheet = .manualEntry
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add manual entry")
                }
            }
            .refreshable { await reload() }
            .task(id: rangeDays) { await reload() }
            .sheet(item: $sheet, onDismiss: handleSheetDismiss) { route in
                switch route {
                case .editClassified(let entry):
                    ClassifyView(entry: entry, mode: .editClassified)
                case .manualEntry:
                    ManualEntryFormView { entry in
                        draftAwaitingClassification = entry
                    }
                case .classifyDraft(let entry):
                    ClassifyView(entry: entry, mode: .classifyDraft)
                }
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

    /// Runs after any sheet dismisses. If the manual-entry form just created a
    /// draft, pivot to ClassifyView for it — deferred to the next runloop tick
    /// so the form's sheet is fully gone before the next one presents (SwiftUI
    /// won't present a second sheet on top of a dismissing one). Otherwise the
    /// list just refreshes to reflect any edit/classification.
    private func handleSheetDismiss() {
        if let draft = draftAwaitingClassification {
            draftAwaitingClassification = nil
            Task { @MainActor in sheet = .classifyDraft(draft) }
        } else {
            Task { await reload() }
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

    /// The sheets HistoryView can present. Collapsing to one enum + a single
    /// `.sheet(item:)` avoids stacking multiple `.sheet` modifiers on one view
    /// (a SwiftUI fragility where only one reliably presents).
    private enum SheetRoute: Identifiable {
        case editClassified(Entry)
        case manualEntry
        case classifyDraft(Entry)

        var id: String {
            switch self {
            case .editClassified(let e): return "edit-\(e.id)"
            case .manualEntry:           return "manual"
            case .classifyDraft(let e):  return "classify-\(e.id)"
            }
        }
    }
}
