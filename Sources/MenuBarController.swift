import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let expandedPanelSize = NSSize(width: 520, height: 620)
    private let parkedPanelSize = NSSize(width: 1, height: 1)
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let viewModel: PlayerViewModel
    private var isParked = false

    init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: expandedPanelSize),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        super.init()

        configureStatusItem()
        configurePanel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainPlayer),
            name: .youtubeBarShowMainPlayer,
            object: nil
        )
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            if let topbarURL = Bundle.main.url(forResource: "topbar", withExtension: "png"),
               let topbarImage = NSImage(contentsOf: topbarURL) {
                topbarImage.size = NSSize(width: 18, height: 18)
                button.image = topbarImage
            } else {
                button.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "YoutubeBar")
            }
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = NSHostingController(rootView: ContentView(viewModel: viewModel))
        panel.setContentSize(expandedPanelSize)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if !panel.isVisible {
            restorePanel(under: button)
            return
        }

        if isParked {
            restorePanel(under: button)
        } else {
            parkPanel()
        }
    }

    @objc
    private func showMainPlayer() {
        guard let button = statusItem.button else { return }
        restorePanel(under: button)
    }

    private func restorePanel(under button: NSStatusBarButton) {
        isParked = false
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.hasShadow = true
        panel.setContentSize(expandedPanelSize)
        positionPanel(under: button, size: expandedPanelSize)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func parkPanel() {
        isParked = true
        panel.resignKey()
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.alphaValue = 0.01
        panel.setContentSize(parkedPanelSize)
        positionPanelInCorner(size: parkedPanelSize)
        panel.orderFrontRegardless()
    }

    private func positionPanel(under button: NSStatusBarButton, size: NSSize) {
        guard let window = button.window else { return }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = window.convertToScreen(buttonFrameInWindow)
        let x = buttonFrameOnScreen.maxX - size.width
        let y = buttonFrameOnScreen.minY - size.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionPanelInCorner(size: NSSize) {
        guard let screen = NSScreen.main ?? panel.screen else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - size.width - 6
        let y = visibleFrame.minY + 6
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
