import AppKit
import Foundation
import Observation
import WebKit

extension Notification.Name {
    static let youtubeBarShowMainPlayer = Notification.Name("youtubeBarShowMainPlayer")
}

@MainActor
@Observable
final class PlayerViewModel {
    var urlText = ""
    var searchQuery = ""
    var isSearchPresented = false
    var searchRequestID = 0
    var playerReloadID = 0
    var webViewAttachmentID = 0
    var isUsingAdoptedSearchWebView = false
    var stagedVideoID: String?
    var stagedVideoTitle = ""
    var stagedVideoURL = ""
    var searchPageURL = ""
    var searchPageTitle = ""
    var searchParsedVideoID = ""
    var applyDiagnosticMessage = ""
    var currentVideoURL: URL?
    var currentVideoID = "jfKfPfyJRdk"
    var currentTitle = "Loading..."
    var currentTime: Double = 0
    var duration: Double = 0
    var isPlaying = false
    var statusMessage = "Paste a YouTube URL and press Load."
    var playerErrorMessage = ""
    var volumeLevel = 50.0
    var smallSeekSeconds = 1.0
    var largeSeekSeconds = 10.0

    var webView: WKWebView?
    weak var searchWebView: WKWebView?

    init() {
        let defaultURL = Self.playerURL(for: currentVideoID)
        currentVideoURL = defaultURL
        urlText = "https://www.youtube.com/watch?v=\(currentVideoID)"
        searchQuery = ""
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func attachSearchWebView(_ webView: WKWebView) {
        searchWebView = webView
    }

    func loadFromInput() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter a YouTube URL first."
            return
        }

        guard let videoID = Self.extractVideoID(from: trimmed) else {
            statusMessage = "Could not parse a YouTube video ID from that URL."
            return
        }

        load(videoID: videoID)
    }

    func load(videoID: String) {
        if isUsingAdoptedSearchWebView {
            rebuildMainWebView()
        }

        currentVideoID = videoID
        currentVideoURL = Self.playerURL(for: videoID)
        urlText = "https://www.youtube.com/watch?v=\(videoID)"
        currentTime = 0
        duration = 0
        currentTitle = "Loading..."
        isPlaying = false
        playerErrorMessage = ""
        statusMessage = "Loaded video \(videoID)."
        playerReloadID += 1
        runPlayerCommand("loadVideoById('\(videoID)')")
    }

    func loadSelectedVideo(videoID: String, title: String?) {
        load(videoID: videoID)
        if let title, !title.isEmpty {
            currentTitle = title
            statusMessage = "Selected \(title)."
        }
        isSearchPresented = false
        requestMainPlayerReveal()
    }

    func stageSelectedVideo(videoID: String, title: String?, url: String) {
        stagedVideoID = videoID
        stagedVideoTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        stagedVideoURL = url
        searchPageURL = url
        searchPageTitle = stagedVideoTitle
        searchParsedVideoID = videoID
        applyDiagnosticMessage = ""
        statusMessage = stagedVideoTitle.isEmpty ? "Video selected in search." : "Ready to apply \(stagedVideoTitle)."
    }

    func applyStagedVideo() {
        applyDiagnosticMessage = ""

        if let stagedVideoID {
            let title = stagedVideoTitle.isEmpty ? nil : stagedVideoTitle
            if adoptSearchWebView(videoID: stagedVideoID, title: title) {
                clearStagedVideo()
                return
            }

            applyDiagnosticMessage =
                """
                Apply fallback path used.
                stagedVideoID: \(stagedVideoID)
                searchWebView attached: \(searchWebView != nil ? "yes" : "no")
                """
            loadSelectedVideo(videoID: stagedVideoID, title: title)
            clearStagedVideo()
            return
        }

        guard let searchWebView else {
            statusMessage = "Search window is not available."
            applyDiagnosticMessage =
                """
                Apply failed.
                Reason: searchWebView is nil
                Current page URL: \(searchPageURL.isEmpty ? "none" : searchPageURL)
                Parsed video ID: \(searchParsedVideoID.isEmpty ? "none" : searchParsedVideoID)
                """
            return
        }

        statusMessage = "Applying current video from search..."
        searchWebView.evaluateJavaScript("({ href: window.location.href, title: document.title })") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.statusMessage = "Could not read the current search page: \(error.localizedDescription)"
                    self.applyDiagnosticMessage =
                        """
                        Apply failed.
                        Reason: JS evaluation error
                        Error: \(error.localizedDescription)
                        Cached page URL: \(self.searchPageURL.isEmpty ? "none" : self.searchPageURL)
                        """
                    return
                }

                let payload = result as? [String: Any]
                let href = payload?["href"] as? String ?? ""
                let rawTitle = payload?["title"] as? String
                let parsedVideoID = Self.extractVideoID(from: href) ?? ""
                self.updateSearchInspection(url: href, title: rawTitle, parsedVideoID: parsedVideoID)

                guard
                    !href.isEmpty,
                    !parsedVideoID.isEmpty
                else {
                    self.statusMessage = "Open a YouTube video in the search window first."
                    self.applyDiagnosticMessage =
                        """
                        Apply failed.
                        Reason: current page is not a parsable YouTube video page
                        Current page URL: \(href.isEmpty ? "none" : href)
                        Current page title: \(rawTitle ?? "none")
                        Parsed video ID: \(parsedVideoID.isEmpty ? "none" : parsedVideoID)
                        """
                    return
                }

                let title = self.normalizedSearchTitle(rawTitle)
                if self.adoptSearchWebView(videoID: parsedVideoID, title: title) {
                    self.clearStagedVideo()
                    return
                }
                self.applyDiagnosticMessage =
                    """
                    Apply fallback path used after live attach failed.
                    Current page URL: \(href)
                    Parsed video ID: \(parsedVideoID)
                    """
                self.loadSelectedVideo(videoID: parsedVideoID, title: title)
                self.clearStagedVideo()
            }
        }
    }

    @discardableResult
    func adoptSearchWebView(videoID: String, title: String?) -> Bool {
        guard let searchWebView else { return false }

        webView = searchWebView
        self.searchWebView = nil
        isUsingAdoptedSearchWebView = true
        currentVideoID = videoID
        currentVideoURL = Self.playerURL(for: videoID)
        urlText = "https://www.youtube.com/watch?v=\(videoID)"
        currentTime = 0
        duration = 0
        isPlaying = true
        playerErrorMessage = ""
        if let title, !title.isEmpty {
            currentTitle = title
            statusMessage = "Selected \(title)."
        } else {
            currentTitle = "Loading..."
            statusMessage = "Applied current search video."
        }
        webViewAttachmentID += 1
        isSearchPresented = false
        requestMainPlayerReveal()
        return true
    }

    func rebuildMainWebView() {
        webView = nil
        isUsingAdoptedSearchWebView = false
        webViewAttachmentID += 1
    }

    func clearStagedVideo() {
        stagedVideoID = nil
        stagedVideoTitle = ""
        stagedVideoURL = ""
    }

    func updateSearchInspection(url: String, title: String?, parsedVideoID: String) {
        searchPageURL = url
        searchPageTitle = normalizedSearchTitle(title) ?? (title ?? "")
        searchParsedVideoID = parsedVideoID
    }

    func normalizedSearchTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " - YouTube Music", with: "")
    }

    func presentSearch() {
        searchRequestID += 1
        clearStagedVideo()
        applyDiagnosticMessage = ""
        isSearchPresented = true
    }

    func playPause() {
        let command = isPlaying ? "pauseVideo()" : "playVideo()"
        runPlayerCommand(command)
    }

    func setVolume(_ value: Double) {
        volumeLevel = min(max(value, 0), 100)
        runPlayerCommand("setVolume(\(volumeLevel / 100.0))")
    }

    func seek(by delta: Double) {
        runPlayerCommand(
            """
            seekBy(\(delta))
            """
        )
    }

    func openInBrowser() {
        let browserURL = URL(string: "https://www.youtube.com/watch?v=\(currentVideoID)")!
        NSWorkspace.shared.open(browserURL)
    }

    func updatePlaybackState(isPlaying: Bool, currentTime: Double, duration: Double, title: String?) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        playerErrorMessage = ""
        if let title, !title.isEmpty {
            currentTitle = title
        }
    }

    func handlePlayerError(code: Int, videoID: String?) {
        let resolvedVideoID = videoID ?? currentVideoID
        playerErrorMessage = switch code {
        case 2:
            "YouTube rejected the video request. The video ID may be invalid."
        case 5:
            "The in-app player could not play this video."
        case 100:
            "This video is unavailable or private."
        case 101, 150:
            "This video blocked in-app playback. Use Open in Browser."
        case 152:
            "This video blocked the old embedded player path. The app now tries the normal YouTube page route."
        default:
            "The in-app player failed with error code \(code)."
        }
        statusMessage = "Player error for \(resolvedVideoID): \(playerErrorMessage)"
    }

    func handlePlayerMessage(_ payload: [String: Any]) {
        let kind = payload["kind"] as? String ?? "state"

        switch kind {
        case "error":
            let code = (payload["code"] as? NSNumber)?.intValue ?? -1
            let videoID = payload["videoId"] as? String
            if code != 0 {
                handlePlayerError(code: code, videoID: videoID)
            }
        default:
            let state = (payload["state"] as? NSNumber)?.intValue ?? 0
            let currentTime = (payload["currentTime"] as? NSNumber)?.doubleValue ?? 0
            let duration = (payload["duration"] as? NSNumber)?.doubleValue ?? 0
            let title = payload["title"] as? String
            updatePlaybackState(
                isPlaying: state == 1,
                currentTime: currentTime,
                duration: duration,
                title: title
            )
        }
    }

    private func requestMainPlayerReveal() {
        NotificationCenter.default.post(name: .youtubeBarShowMainPlayer, object: nil)
    }

    private func runPlayerCommand(_ body: String) {
        webView?.evaluateJavaScript("window.youtubeBar.\(body);", completionHandler: nil)
    }

    static func extractVideoID(from rawValue: String) -> String? {
        guard let url = URL(string: rawValue), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return rawValue.count == 11 ? rawValue : nil
        }

        if let host = components.host?.lowercased() {
            if host.contains("youtu.be") {
                return url.pathComponents.dropFirst().first
            }

            if host.contains("youtube.com") {
                if url.path == "/watch" {
                    return components.queryItems?.first(where: { $0.name == "v" })?.value
                }

                if url.path.hasPrefix("/embed/") || url.path.hasPrefix("/shorts/") {
                    return url.pathComponents.dropFirst(2).first
                }
            }
        }

        return nil
    }

    static func playerURL(for videoID: String) -> URL? {
        URL(string: "https://m.youtube.com/watch?v=\(videoID)&playsinline=1&app=m")
    }

    static func formattedTime(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let totalSeconds = Int(value.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
