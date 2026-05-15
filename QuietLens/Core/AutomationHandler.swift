import AppKit

@MainActor
final class AutomationHandler {
    func handle(url: URL) {
        let host = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
        switch host {
        case "toggle": AppDelegate.shared.toggleOverlay()
        case "enable": AppDelegate.shared.overlayManager.setEnabled(true, animated: true)
        case "disable": AppDelegate.shared.overlayManager.setEnabled(false, animated: true)
        case "settings": AppDelegate.shared.openSettings()
        default: NSLog("QuietLens: unknown URL command \(host)")
        }
    }
}
