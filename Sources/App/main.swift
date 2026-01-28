import AppKit
import SwiftUI

// Entry point - utilise MainActor.assumeIsolated pour Swift 6
@MainActor
func runApp() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}

// Lance l'app sur le MainActor
MainActor.assumeIsolated {
    runApp()
}
