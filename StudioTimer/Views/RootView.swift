// StudioTimer/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.apiClient) private var api

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                LoginView()
            } else if appState.selectedWorkspaceID == nil {
                WorkspacePickerView()
            } else {
                StudioShellView()
            }
        }
        .task {
            // Hydrate workspaces / user info from the server on launch when
            // we have a JWT (Keychain) but no cached workspace list. This is
            // the typical post-uninstall state — Keychain survives, but
            // UserDefaults (which holds availableWorkspaces' source-of-truth
            // entry point via didLogIn) does not — so without this refresh
            // we'd be stuck on an empty workspace picker.
            //
            // Also re-runs whenever isAuthenticated flips to true (e.g. after
            // logging in fresh) which is a harmless no-op since didLogIn
            // already populated the list.
            if appState.isAuthenticated && appState.availableWorkspaces.isEmpty {
                await appState.refreshFromServer(api: api)
            }
        }
    }
}

/// The authenticated home of the app: a full-screen Studio WebView with
/// the native Timer flow available as a modal `.fullScreenCover`. The
/// modal is triggered from `AppRouter.openTimer()`, which the WebView's
/// navigation delegate calls when the user taps a `/time` link in the web
/// app's nav.
private struct StudioShellView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.apiClient) private var api
    @StateObject private var webState = StudioWebViewStateHolder()

    var body: some View {
        ZStack {
            StudioWebView(
                baseURL: AppState.apiBaseURL,
                router: router,
                api: api,
                state: webState
            )
            .ignoresSafeArea()

            if webState.isLoading && webState.loadError == nil {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
            }

            if let err = webState.loadError {
                VStack(spacing: 16) {
                    Text("Couldn't load Studio")
                        .font(.headline)
                    Text(err.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { webState.reload() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                .padding()
                .background(Theme.base200.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
                .padding()
            }
        }
        .fullScreenCover(isPresented: $router.showingTimer) {
            NavigationStack {
                RootTabView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { router.closeTimer() }
                        }
                    }
            }
        }
    }
}
