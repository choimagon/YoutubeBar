import SwiftUI
import WebKit

struct YouTubeSearchSheetView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Button("Apply") {
                    viewModel.applyStagedVideo()
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    viewModel.isSearchPresented = false
                }
                .buttonStyle(.bordered)
            }

            if !viewModel.applyDiagnosticMessage.isEmpty {
                Text(viewModel.applyDiagnosticMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
                    .textSelection(.enabled)
            }

            YouTubeSearchWebView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 560)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(width: 760, height: 660)
    }
}

struct YouTubeSearchWebView: NSViewRepresentable {
    let viewModel: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = makeYoutubeBarWebView(
            scriptHandler: context.coordinator,
            navigationDelegate: context.coordinator,
            allowsBackForwardNavigationGestures: true,
            mode: "search"
        )
        viewModel.attachSearchWebView(webView)
        context.coordinator.loadSearch(in: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let normalizedQuery = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if context.coordinator.lastLoadedQuery != normalizedQuery || context.coordinator.lastRequestID != viewModel.searchRequestID {
            guard viewModel.isSearchPresented else { return }
            context.coordinator.loadSearch(in: nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let viewModel: PlayerViewModel
        var lastLoadedQuery = ""
        var lastRequestID = 0

        init(viewModel: PlayerViewModel) {
            self.viewModel = viewModel
        }

        func loadSearch(in webView: WKWebView) {
            let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            lastLoadedQuery = query
            lastRequestID = viewModel.searchRequestID

            if query.isEmpty {
                webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
            } else {
                var components = URLComponents(string: "https://m.youtube.com/results")!
                components.queryItems = [URLQueryItem(name: "search_query", value: query)]
                webView.load(URLRequest(url: components.url!))
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("({ href: window.location.href, title: document.title })") { [weak self] result, _ in
                Task { @MainActor in
                    guard let self else { return }
                    guard let payload = result as? [String: Any] else {
                        return
                    }

                    let href = payload["href"] as? String ?? ""
                    let rawTitle = payload["title"] as? String
                    let videoID = PlayerViewModel.extractVideoID(from: href) ?? ""
                    self.viewModel.updateSearchInspection(url: href, title: rawTitle, parsedVideoID: videoID)

                    guard !videoID.isEmpty else { return }

                    let title = self.viewModel.normalizedSearchTitle(rawTitle)
                    self.viewModel.stageSelectedVideo(videoID: videoID, title: title, url: href)
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                message.name == "playerState",
                let payload = message.body as? [String: Any]
            else {
                return
            }

            Task { @MainActor in
                self.viewModel.handlePlayerMessage(payload)
            }
        }
    }
}
