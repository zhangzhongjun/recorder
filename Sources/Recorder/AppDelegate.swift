import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowController: OverlayWindowController?
    var store = TranscriptionStore()
    var notesStore = NotesStore()

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
        menu.addItem(NSMenuItem(title: "显示/隐藏备忘录", action: #selector(toggleNotes), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupOverlayWindow() {
        overlayWindowController = OverlayWindowController(store: store, notesStore: notesStore)
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

    @objc func toggleNotes() {
        notesStore.showPanel.toggle()
        // 备忘录面板隐藏时确保主窗口可见
        if notesStore.showPanel, overlayWindowController?.window?.isVisible == false {
            overlayWindowController?.showWindow(nil)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
