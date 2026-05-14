// StudioTimer/Views/StudioWebView.swift
import SwiftUI
import WebKit

/// External state shared between StudioWebView (the UIViewRepresentable) and
/// the SwiftUI parent. Lives outside StudioWebView itself because
/// UIViewRepresentable can't directly publish state to its parent during
/// the same render cycle.
@MainActor
final class StudioWebViewStateHolder: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var loadError: Error?
    weak var webView: WKWebView?

    func reload() { webView?.reload() }
}

struct StudioWebView: UIViewRepresentable {
    let baseURL: URL
    @ObservedObject var router: AppRouter
    let api: APIClient
    let state: StudioWebViewStateHolder

    func makeCoordinator() -> Coordinator {
        Coordinator(router: router, api: api, baseURL: baseURL, state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.customUserAgent = Self.makeUserAgent()
        web.scrollView.refreshControl = context.coordinator.makeRefreshControl()

        context.coordinator.webView = web
        state.webView = web

        // Run the bootstrap auth-exchange flow exactly once per Coordinator
        // lifetime. SwiftUI does not promise a single makeUIView call.
        if !context.coordinator.didBootstrap {
            context.coordinator.didBootstrap = true
            Task { @MainActor in
                await context.coordinator.bootstrap()
            }
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op; navigation is driven by the coordinator and router.
    }

    private static func makeUserAgent() -> String {
        // Append a marker so the web app can detect that it's rendered
        // inside the iOS shell (e.g. to hide a 'Download our iOS app' banner).
        let defaultUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        return defaultUA + " StudioApp/1.0"
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let router: AppRouter
        let api: APIClient
        let baseURL: URL
        let state: StudioWebViewStateHolder
        weak var webView: WKWebView?
        var didBootstrap = false

        init(router: AppRouter, api: APIClient, baseURL: URL, state: StudioWebViewStateHolder) {
            self.router = router
            self.api = api
            self.baseURL = baseURL
            self.state = state
        }

        // MARK: - Bootstrap auth handoff

        func bootstrap() async {
            // Try to pre-authenticate the WebView via the exchange flow.
            // If the user isn't logged in natively (no JWT), fall through to
            // loading the studio root, which shows the studio login page.
            do {
                let token = try await api.exchangeToken()
                let url = baseURL.appendingPathComponent("/auth/exchange")
                var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                comps.queryItems = [URLQueryItem(name: "token", value: token)]
                webView?.load(URLRequest(url: comps.url!))
            } catch {
                webView?.load(URLRequest(url: baseURL))
            }
        }

        // MARK: - Navigation interception

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else {
                decisionHandler(.allow); return
            }

            // External domains open in Safari.
            if let host = url.host, host != baseURL.host {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }

            // /time, /time/track and friends open the native Timer modal
            // instead of navigating.
            if url.path == "/time" || url.path.hasPrefix("/time/") {
                decisionHandler(.cancel)
                router.openTimer()
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - Loading state

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.loadError = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            state.loadError = error
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            state.loadError = error
        }

        // MARK: - Pull-to-refresh

        func makeRefreshControl() -> UIRefreshControl {
            let rc = UIRefreshControl()
            rc.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
            return rc
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.endRefreshing()
            }
        }
    }
}
