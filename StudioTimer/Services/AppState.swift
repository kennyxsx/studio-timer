// StudioTimer/Services/AppState.swift  -- create
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var selectedWorkspaceID: String?
    @Published var availableWorkspaces: [Workspace] = []
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(keychain: KeychainStore = KeychainStore(), defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
        self.isAuthenticated = (keychain.accessToken != nil)
        self.selectedWorkspaceID = defaults.string(forKey: "selected_workspace_id")
    }

    func didLogIn(workspaces: [Workspace], user: APIClient.LoginResponse.User) {
        availableWorkspaces = workspaces
        currentUserName = user.name
        currentUserEmail = user.email
        if workspaces.count == 1 {
            setWorkspace(workspaces[0].id)
        }
        isAuthenticated = true
    }

    func setWorkspace(_ id: String) {
        selectedWorkspaceID = id
        defaults.set(id, forKey: "selected_workspace_id")
    }

    func logout() {
        keychain.clearAll()
        defaults.removeObject(forKey: "selected_workspace_id")
        selectedWorkspaceID = nil
        availableWorkspaces = []
        currentUserName = nil
        currentUserEmail = nil
        isAuthenticated = false
    }
}
