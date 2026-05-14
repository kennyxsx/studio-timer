// StudioTimer/Services/AppRouter.swift
import Foundation
import Combine

/// Coordinates cross-surface navigation between the Studio WebView and
/// the native Timer modal. Owned by `StudioTimerApp` and observed by the
/// root view's `.fullScreenCover(isPresented:)`.
@MainActor
final class AppRouter: ObservableObject {
    /// When true, the native Timer flow is presented as a full-screen modal
    /// over the Studio WebView. Toggled by the WebView's navigation
    /// interceptor on /time URLs, and by the Timer's own dismiss button.
    @Published var showingTimer: Bool = false

    func openTimer() {
        showingTimer = true
    }

    func closeTimer() {
        showingTimer = false
    }
}
