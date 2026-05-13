// StudioTimer/Views/WorkspacePickerView.swift
import SwiftUI

struct WorkspacePickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Theme.base100.ignoresSafeArea()

            VStack {
                Text("Select a workspace")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.primary)
                    .padding(.top, 40)
                List(appState.availableWorkspaces) { ws in
                    Button {
                        appState.setWorkspace(ws.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ws.name).font(.headline)
                                Text(ws.role).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.base100)
            }
        }
    }
}
