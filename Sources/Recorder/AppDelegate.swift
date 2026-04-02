import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowController: OverlayWindowController?
    var store = TranscriptionStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupOverlayWindow()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Recorder")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏字幕窗口", action: #selector(toggleOverlay), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupOverlayWindow() {
        overlayWindowController = OverlayWindowController(store: store)
        overlayWindowController?.showWindow(nil)
    }

    @objc func toggleOverlay() {
        guard let wc = overlayWindowController else { return }
        if wc.window?.isVisible == true {
            wc.window?.orderOut(nil)
        } else {
            wc.showWindow(nil)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
