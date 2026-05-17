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

    /// Refreshes the user profile + workspace list from /api/mobile/me.
    /// Called on app launch when the JWT survived (e.g. across an uninstall —
    /// Keychain persists, UserDefaults doesn't, so availableWorkspaces is
    /// empty and we'd otherwise land on a picker with no rows).
    ///
    /// Also auto-selects the workspace when exactly one is available, mirroring
    /// the post-login flow in didLogIn(workspaces:user:).
    func refreshFromServer(api: APIClient) async {
        do {
            let me = try await api.me()
            availableWorkspaces = me.workspaces
            currentUserName = me.user.name
            currentUserEmail = me.user.email
            if selectedWorkspaceID == nil && me.workspaces.count == 1 {
                setWorkspace(me.workspaces[0].id)
            } else if let sel = selectedWorkspaceID,
                      !me.workspaces.contains(where: { $0.id == sel }) {
                // Cached workspace ID is no longer one the user has access to.
                selectedWorkspaceID = nil
                defaults.removeObject(forKey: "selected_workspace_id")
            }
        } catch APIError.unauthorized {
            // JWT was rejected (e.g. revoked server-side). Fall back to login.
            logout()
        } catch {
            // Network errors etc. — leave state as-is; user can retry by
            // re-opening the app or by signing in again.
        }
    }

    func logout() {
        keychain.clearAll()
        defaults.removeObject(forKey: "selected_workspace_id")
        selectedWorkspaceID = nil
        availableWorkspaces = []
        currentUserName = nil
        currentUserEmail = nil
        isAuthenticated = false
        // Clear the Studio WebView's session cookie too — otherwise next
        // launch the WebView still shows the previous user's authenticated
        // state. Runs in the background; doesn't block the sync state flip.
        Task { @MainActor in await WebCookieStore.clearStudioCookies() }
    }
}
