import AppKit
import SwiftUI

class OverlayWindowController: NSWindowController {
    private let store: TranscriptionStore
    private let viewModel: RecorderViewModel

    init(store: TranscriptionStore) {
        self.store = store
        self.viewModel = RecorderViewModel(store: store)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        // Position: bottom center of screen, 700x240
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 260
        let windowX = screenFrame.midX - windowWidth / 2
        let windowY = screenFrame.minY + 40

        let window = OverlayWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        let contentView = ContentView(store: store, viewModel: viewModel)
        window.contentView = NSHostingView(rootView: contentView)
        window.setFrameAutosaveName("RecorderOverlay")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class OverlayWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        configure()
    }

    private func configure() {
        // Always on top, above fullscreen apps
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Invisible to screen recording / screen sharing (Zoom, 飞书投屏等)
        sharingType = .none
        minSize = NSSize(width: 400, height: 150)
        maxSize = NSSize(width: 1200, height: 600)
        isReleasedWhenClosed = false
    }

    // Allow keyboard shortcuts even when not key window
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
