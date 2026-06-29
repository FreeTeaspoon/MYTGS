import SwiftUI
import WebKit

struct LoginWebView: NSViewRepresentable {
    var url: URL
    var onToken: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onToken: (String) -> Void

        init(onToken: @escaping (String) -> Void) {
            self.onToken = onToken
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            inspect(webView.url)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            inspect(navigationAction.request.url)
            decisionHandler(.allow)
        }

        private func inspect(_ url: URL?) {
            guard let url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                  !token.isEmpty else {
                return
            }
            onToken(token)
        }
    }
}

struct WebHTMLView: NSViewRepresentable {
    var html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let body = html.isEmpty ? "<p>EPR not loaded.</p>" : html
        let page = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body { font: -apple-system-body; color: -apple-system-label; background: transparent; }
        table { width: 100%; border-collapse: collapse; }
        td, th { border-bottom: 1px solid color-mix(in srgb, currentColor 20%, transparent); padding: 6px; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
        nsView.loadHTMLString(page, baseURL: nil)
    }
}
