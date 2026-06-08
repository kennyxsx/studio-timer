// StudioTimer/Views/ClassifyView.swift
import SwiftUI

struct ClassifyView: View {
    enum Mode {
        case classifyDraft
        case editClassified
    }

    let entry: Entry
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var api
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: TimerStore

    @State private var shape: ShapeTab = .internalOverhead
    @State private var durationMinutes: Int = 0
    @State private var category: String = ""
    @State private var notes: String = ""
    @State private var selectedCustomerID: String?
    @State private var splits: [DraftSplit] = []
    @State private var isSaving: Bool = false
    @State private var errorText: String?

    @State private var allProjects: [Project] = []
    @State private var allCustomers: [Customer] = []
    @State private var categorySuggestions: [String] = []

    @State private var showingProjectPicker = false
    @State private var showingCustomerPicker = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case category
        case notes
    }

    enum ShapeTab: String, CaseIterable {
        case project = "Project"
        case customer = "Customer"
        case internalOverhead = "Internal"
    }

    struct DraftSplit: Identifiable, Equatable {
        let id = UUID()
        var projectID: String
        var projectName: String
        var percentage: Double
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    DurationField(totalMinutes: $durationMinutes)
                }

                Section("Shape") {
                    Picker("Shape", selection: $shape) {
                        ForEach(ShapeTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch shape {
                    case .project:
                        projectSection
                    case .customer:
                        customerSection
                    case .internalOverhead:
                        EmptyView()
                    }
                }

                Section("Category") {
                    TextField("e.g. Shoot, Editing, Admin", text: $category)
                        .focused($focusedField, equals: .category)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .notes }
                    if !categorySuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(categorySuggestions, id: \.self) { suggestion in
                                    Button(suggestion) { category = suggestion }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .focused($focusedField, equals: .notes)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.base100)
            .navigationTitle(mode == .classifyDraft ? "Classify" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .task { await loadLookups() }
            .sheet(isPresented: $showingProjectPicker) {
                let selectedIDs = Set(splits.map { $0.projectID })
                let available = allProjects.filter { !selectedIDs.contains($0.id) }
                ProjectPickerView(projects: available) { project in
                    addProject(project)
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                CustomerPickerView(customers: allCustomers, selectedID: $selectedCustomerID)
            }
            .onAppear {
                durationMinutes = entry.durationMinutes
                category = entry.category ?? ""
                notes = entry.notes ?? ""
                selectedCustomerID = entry.customerUserID
                splits = entry.splits.map { s in
                    DraftSplit(projectID: s.projectID, projectName: "...", percentage: s.percentage)
                }
                if !splits.isEmpty { shape = .project }
                else if selectedCustomerID != nil { shape = .customer }
                else { shape = .internalOverhead }
            }
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        ForEach(splits) { split in
            HStack {
                Text(split.projectName)
                Spacer()
                Text(String(format: "%.0f%%", split.percentage))
                    .foregroundStyle(.secondary)
                Button {
                    removeSplit(id: split.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(split.projectName)")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    removeSplit(id: split.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        Button("Add project…") { showingProjectPicker = true }
        if splits.count > 1 {
            ForEach($splits) { $split in
                VStack(alignment: .leading) {
                    Text(split.projectName).font(.caption).foregroundStyle(.secondary)
                    // Rebalance only when the user lifts their finger (editing == false).
                    // Updating during drag triggers cascading .onChange writes across the
                    // other sliders and creates a feedback loop with 3+ projects.
                    Slider(
                        value: $split.percentage,
                        in: 0...100,
                        step: 5,
                        onEditingChanged: { editing in
                            if !editing {
                                rebalanceSplits(except: split.id)
                            }
                        }
                    )
                }
            }
        }
    }

    private func removeSplit(id: UUID) {
        splits.removeAll { $0.id == id }
        rebalanceSplits()
    }

    @ViewBuilder
    private var customerSection: some View {
        if let id = selectedCustomerID,
           let cust = allCustomers.first(where: { $0.id == id }) {
            HStack {
                Text(cust.name)
                Spacer()
                Button("Change") { showingCustomerPicker = true }
            }
        } else {
            Button("Select customer…") { showingCustomerPicker = true }
        }
    }

    private var canSave: Bool {
        guard durationMinutes >= 1 else { return false }
        switch shape {
        case .project:
            let sum = splits.reduce(0) { $0 + $1.percentage }
            return !splits.isEmpty && abs(sum - 100) < 0.1
        case .customer:
            return selectedCustomerID != nil
        case .internalOverhead:
            return !category.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func addProject(_ project: Project) {
        splits.append(.init(projectID: project.id, projectName: project.name, percentage: 0))
        rebalanceSplits()
    }

    private func rebalanceSplits(except: UUID? = nil) {
        guard !splits.isEmpty else { return }
        if splits.count == 1 {
            splits[0].percentage = 100
            return
        }
        // Distribute remaining percentage equally across non-fixed splits.
        let fixed = splits.first(where: { $0.id == except })
        let fixedSum = fixed?.percentage ?? 0
        let remaining = 100 - fixedSum
        let nonFixedCount = splits.count - (fixed == nil ? 0 : 1)
        guard nonFixedCount > 0 else { return }
        let share = remaining / Double(nonFixedCount)
        for i in splits.indices where splits[i].id != except {
            splits[i].percentage = share
        }
    }

    private func loadLookups() async {
        guard let wsID = appState.selectedWorkspaceID else { return }
        async let projectsTask = api.listProjects(workspaceID: wsID)
        async let customersTask = api.listCustomers(workspaceID: wsID)
        async let categoriesTask = api.listCategories(workspaceID: wsID)
        do {
            self.allProjects = try await projectsTask
            self.allCustomers = try await customersTask
            self.categorySuggestions = try await categoriesTask
            // Fill in project names on existing splits, if any.
            for i in self.splits.indices {
                if let p = self.allProjects.first(where: { $0.id == self.splits[i].projectID }) {
                    self.splits[i].projectName = p.name
                }
            }
        } catch {
            // non-fatal; user can retry by reopening the sheet
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorText = nil

        // Build the patch. customerUserID semantics:
        //   - Customer shape: send the selected ID (or leave nil if not selected — UI prevents save in that case)
        //   - Project / Internal shapes: clearCustomer=true sends explicit null so the backend
        //     drops any previously-set customer when re-classifying.
        var patch = APIClient.PatchEntryRequest(
            durationMinutes: durationMinutes,
            splits: shape == .project
                ? splits.map { .init(projectID: $0.projectID, percentage: $0.percentage) }
                : [],
            category: category.isEmpty ? nil : category,
            notes: notes.isEmpty ? nil : notes,
            status: "classified")
        if shape == .customer {
            patch.customerUserID = selectedCustomerID
        } else {
            patch.clearCustomer = true
        }

        do {
            let updated = try await api.updateEntry(entry.id, patch: patch)
            store.updateDraft(updated)
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
