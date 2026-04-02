import AppKit

// AppDelegate is @MainActor; dispatch its creation to the main actor
let app = NSApplication.shared

// Run synchronously on main thread (this IS the main thread at startup)
MainActor.assumeIsolated {
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
}

app.run()
