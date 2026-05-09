import SwiftUI
import WebKit

func youtubeBarHelperScriptSource(mode: String) -> String {
"""
(function() {
  if (window.youtubeBar) { return; }
  window.youtubeBarMode = '\(mode)';

  function injectStyles() {
    if (document.getElementById('youtube-bar-style')) { return; }
    const style = document.createElement('style');
    style.id = 'youtube-bar-style';
    style.textContent = `
      html, body {
        margin: 0 !important;
        background: #000 !important;
        color-scheme: dark !important;
      }
    `;
    document.head.appendChild(style);
  }

  function findVideo() {
    return document.querySelector('video');
  }

  function readTitle() {
    return (document.title || '').replace(' - YouTube', '').replace(' - YouTube Music', '');
  }

  function readVideoId() {
    try {
      const url = new URL(window.location.href);
      if (url.pathname === '/watch') {
        return url.searchParams.get('v') || '';
      }
      const parts = url.pathname.split('/').filter(Boolean);
      if (parts.length >= 2 && (parts[0] === 'shorts' || parts[0] === 'embed')) {
        return parts[1];
      }
    } catch (_) {}
    return '';
  }

  function postState(kind, code) {
    const video = findVideo();
    window.webkit.messageHandlers.playerState.postMessage({
      kind: kind || 'state',
      code: code || 0,
      state: video ? (video.paused ? 2 : 1) : 0,
      currentTime: video ? video.currentTime : 0,
      duration: video ? video.duration || 0 : 0,
      title: readTitle(),
      videoId: readVideoId()
    });
  }

  function installObservers() {
    injectStyles();
    const video = findVideo();
    if (!video || video.dataset.youtubeBarBound === '1') { return; }
    video.dataset.youtubeBarBound = '1';
    ['play', 'pause', 'seeked', 'loadedmetadata', 'timeupdate', 'ended'].forEach(function(eventName) {
      video.addEventListener(eventName, function() { postState('state', 0); });
    });
    postState('state', 0);
  }

  function resumePlayback() {
    const video = findVideo();
    if (!video) { return; }
    video.muted = false;
    if (typeof window.youtubeBarDesiredVolume === 'number') {
      video.volume = Math.max(0, Math.min(1, window.youtubeBarDesiredVolume));
    }
    const promise = video.play();
    if (promise && typeof promise.catch === 'function') {
      promise.catch(function() {});
    }
    postState('state', 0);
  }

  setInterval(installObservers, 1000);
  setInterval(function() { postState('state', 0); }, 1000);

  document.addEventListener('visibilitychange', function() {
    if (!document.hidden) {
      setTimeout(resumePlayback, 50);
    }
  });

  window.youtubeBar = {
    playVideo: function() {
      resumePlayback();
    },
    pauseVideo: function() {
      const video = findVideo();
      if (video) { video.pause(); }
    },
    setVolume: function(value) {
      const video = findVideo();
      window.youtubeBarDesiredVolume = Math.max(0, Math.min(1, value));
      if (video) {
        video.volume = Math.max(0, Math.min(1, value));
        video.muted = value <= 0;
        postState('state', 0);
      }
    },
    seekBy: function(delta) {
      const video = findVideo();
      if (video) {
        video.currentTime = Math.max(video.currentTime + delta, 0);
        postState('state', 0);
      }
    },
    loadVideoById: function(videoId) {
      window.location.href = 'https://m.youtube.com/watch?v=' + encodeURIComponent(videoId) + '&playsinline=1&app=m';
    }
  };

  injectStyles();
  installObservers();
})();
"""
}

@MainActor
func makeYoutubeBarWebView(
    scriptHandler: WKScriptMessageHandler,
    navigationDelegate: WKNavigationDelegate,
    allowsBackForwardNavigationGestures: Bool,
    mode: String
) -> WKWebView {
    let contentController = WKUserContentController()
    contentController.add(scriptHandler, name: "playerState")
    contentController.addUserScript(WKUserScript(source: youtubeBarHelperScriptSource(mode: mode), injectionTime: .atDocumentEnd, forMainFrameOnly: true))

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    configuration.allowsAirPlayForMediaPlayback = true
    configuration.preferences.isElementFullscreenEnabled = true
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.websiteDataStore = .default()

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
    webView.isInspectable = true
    webView.navigationDelegate = navigationDelegate
    return webView
}

@MainActor
final class HostedWebViewContainer: NSView {
    func host(_ webView: WKWebView) {
        for subview in subviews where subview !== webView {
            subview.removeFromSuperview()
        }

        if webView.superview !== self {
            webView.removeFromSuperview()
            addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: trailingAnchor),
                webView.topAnchor.constraint(equalTo: topAnchor),
                webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }
}

struct YouTubeWebView: NSViewRepresentable {
    let viewModel: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> HostedWebViewContainer {
        let container = HostedWebViewContainer()
        let webView = viewModel.webView ?? makeYoutubeBarWebView(
            scriptHandler: context.coordinator,
            navigationDelegate: context.coordinator,
            allowsBackForwardNavigationGestures: false,
            mode: "player"
        )
        viewModel.attach(webView: webView)
        container.host(webView)
        if context.coordinator.hostedWebView == nil {
            context.coordinator.hostedWebView = webView
            context.coordinator.loadInitialPlayer(in: webView, videoID: viewModel.currentVideoID)
        }
        return container
    }

    func updateNSView(_ nsView: HostedWebViewContainer, context: Context) {
        if viewModel.webView == nil || context.coordinator.lastAttachmentID != viewModel.webViewAttachmentID {
            let newWebView = makeYoutubeBarWebView(
                scriptHandler: context.coordinator,
                navigationDelegate: context.coordinator,
                allowsBackForwardNavigationGestures: false,
                mode: "player"
            )
            viewModel.attach(webView: newWebView)
            nsView.host(newWebView)
            context.coordinator.hostedWebView = newWebView
            context.coordinator.loadInitialPlayer(in: newWebView, videoID: viewModel.currentVideoID)
            return
        }

        let webView = viewModel.webView!
        viewModel.attach(webView: webView)
        nsView.host(webView)

        if context.coordinator.hostedWebView !== webView {
            context.coordinator.hostedWebView = webView
            context.coordinator.lastLoadedVideoID = viewModel.currentVideoID
            context.coordinator.lastReloadID = viewModel.playerReloadID
            context.coordinator.didLoadInitialPlayer = true
            context.coordinator.applyPlaybackState(in: webView)
            return
        }

        if context.coordinator.lastLoadedVideoID != viewModel.currentVideoID || context.coordinator.lastReloadID != viewModel.playerReloadID {
            context.coordinator.replaceVideo(in: webView, videoID: viewModel.currentVideoID)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let viewModel: PlayerViewModel
        var lastLoadedVideoID: String?
        var lastReloadID = 0
        var lastAttachmentID = 0
        var didLoadInitialPlayer = false
        weak var hostedWebView: WKWebView?

        init(viewModel: PlayerViewModel) {
            self.viewModel = viewModel
        }

        func loadInitialPlayer(in webView: WKWebView, videoID: String) {
            lastAttachmentID = viewModel.webViewAttachmentID
            lastLoadedVideoID = videoID
            lastReloadID = viewModel.playerReloadID
            didLoadInitialPlayer = true
            if let url = PlayerViewModel.playerURL(for: videoID) {
                webView.load(URLRequest(url: url))
            }
        }

        func replaceVideo(in webView: WKWebView, videoID: String) {
            lastLoadedVideoID = videoID
            lastReloadID = viewModel.playerReloadID

            guard didLoadInitialPlayer else {
                loadInitialPlayer(in: webView, videoID: videoID)
                return
            }

            webView.evaluateJavaScript("window.youtubeBar.loadVideoById('\(videoID)')") { _, error in
                if error != nil {
                    if let url = PlayerViewModel.playerURL(for: videoID) {
                        webView.load(URLRequest(url: url))
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyPlaybackState(in: webView)
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

        func applyPlaybackState(in webView: WKWebView) {
            let normalizedVolume = max(0, min(1, viewModel.volumeLevel / 100.0))
            let script =
            """
            window.youtubeBarDesiredVolume = \(normalizedVolume);
            if (window.youtubeBar) {
              window.youtubeBar.setVolume(\(normalizedVolume));
              window.youtubeBar.playVideo();
            }
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}
