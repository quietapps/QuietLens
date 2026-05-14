import SwiftUI
import AppKit
import ApplicationServices

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var trusted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer?
    @State private var checkFailedMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "circle.lefthalf.filled").font(.system(size: 56))
            Text("Welcome to FocusLens").font(.title)
            Text("FocusLens needs Accessibility access to detect which window you're focused on so it can dim everything else.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)
            if trusted {
                Text("✓ Permission granted").foregroundStyle(.green)
                Button("Continue") { onDone() }.buttonStyle(.borderedProminent)
            } else {
                Button("Open System Settings") { openAXSettings() }.buttonStyle(.borderedProminent)
                Button("I've granted access") { recheck() }
                if let msg = checkFailedMessage {
                    Text(msg).font(.callout).foregroundStyle(.orange).multilineTextAlignment(.center).frame(maxWidth: 440)
                }
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Already granted but still not working?").font(.headline)
                    Text("macOS ties Accessibility permission to the app's code signature. After rebuilding the app, the old entry no longer matches. Fix:")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("1. Open System Settings → Privacy & Security → Accessibility")
                    Text("2. Select FocusLens and click the – button to remove it")
                    Text("3. Click + and add FocusLens again (or drag from /Applications)")
                    Text("4. Toggle it ON")
                }
                .font(.callout)
                .frame(maxWidth: 440, alignment: .leading)
            }
        }
        .padding(28)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                trusted = AXIsProcessTrusted()
                if trusted { timer?.invalidate() }
            }
        }
        .onChange(of: trusted) { _, newValue in
            if newValue { onDone() }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func recheck() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let t = AXIsProcessTrustedWithOptions(opts)
        trusted = t
        if t {
            checkFailedMessage = nil
            onDone()
        } else {
            checkFailedMessage = "macOS still reports access not granted. The app's code signature likely changed since you granted permission. Remove FocusLens from the Accessibility list and add it again."
        }
    }

    private func openAXSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
