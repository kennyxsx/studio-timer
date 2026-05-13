// StudioTimer/Views/ProjectPickerView.swift
import SwiftUI

struct ProjectPickerView: View {
    let projects: [Project]
    let onSelect: (Project) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filtered: [Project] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { project in
                Button {
                    onSelect(project)
                    dismiss()
                } label: {
                    Text(project.name)
                }
            }
            .searchable(text: $searchText, prompt: "Search projects")
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
