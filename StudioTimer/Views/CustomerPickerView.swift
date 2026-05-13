// StudioTimer/Views/CustomerPickerView.swift
import SwiftUI

struct CustomerPickerView: View {
    let customers: [Customer]
    @Binding var selectedID: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filtered: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { customer in
                Button {
                    selectedID = customer.id
                    dismiss()
                } label: {
                    HStack {
                        Text(customer.name)
                        Spacer()
                        if selectedID == customer.id {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search customers")
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
