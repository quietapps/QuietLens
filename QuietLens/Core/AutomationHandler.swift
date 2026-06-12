import AppKit

@MainActor
final class AutomationHandler {
    func handle(url: URL) {
        let host = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
        switch host {
        case "toggle": AppDelegate.shared.toggleOverlay()
        case "enable": AppDelegate.shared.setOverlayEnabled(true)
        case "disable": AppDelegate.shared.setOverlayEnabled(false)
        case "settings": AppDelegate.shared.openSettings()
        default: NSLog("QuietLens: unknown URL command \(host)")
        }
    }
}
