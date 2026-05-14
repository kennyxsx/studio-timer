// StudioTimer/Services/WebCookieStore.swift
import Foundation
import WebKit

enum WebCookieStore {
    /// Clears all cookies for `studio.ivy-s.de` (and any subdomain of `ivy-s.de`)
    /// from the shared WKWebsiteDataStore. Used on native logout so the Studio
    /// WebView shows the login screen next time.
    ///
    /// Filter is tight: an exact host match plus a `.ivy-s.de` suffix match.
    /// `contains("studio")` would also hit unrelated third-party cookies
    /// (analytics, fonts, embedded widgets) whose domain happens to include
    /// the word "studio".
    @MainActor
    static func clearStudioCookies() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await store.allCookies()
        let targets = cookies.filter { c in
            c.domain == "studio.ivy-s.de" || c.domain.hasSuffix(".ivy-s.de")
        }
        for c in targets {
            await store.deleteCookie(c)
        }
    }
}
