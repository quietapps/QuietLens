import SwiftUI
import AppKit
import ApplicationServices

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var trusted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer?
    @State private var checkFailedMessage: String?

    var body: some View {
        ZStack {
            WallpaperBackground()
            VStack(spacing: FL.S.s5) {
                Spacer().frame(height: FL.S.s7)
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high)
                    .frame(width: 96, height: 96)
                    .padding(FL.S.s4)
                    .background(
                        RoundedRectangle(cornerRadius: FL.R.cardLg, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FL.R.cardLg, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 12)

                Text("Welcome to FocusLens").font(FL.T.display())
                Text("Dim everything except the window you're working in. FocusLens needs Accessibility access to detect which window is focused.")
                    .font(FL.T.bodyR())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)

                HStack(spacing: 8) {
                    Circle().fill(trusted ? FL.C.green : FL.C.orange).frame(width: 8, height: 8)
                        .shadow(color: (trusted ? FL.C.green : FL.C.orange).opacity(0.7), radius: 4)
                    Text(trusted ? "Accessibility · Granted" : "Accessibility · Not granted")
                        .font(FL.T.body())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, FL.S.s3).padding(.vertical, 6)
                .background(
                    Capsule().fill(.thinMaterial)
                )

                HStack(spacing: 8) {
                    if trusted {
                        PrimaryButton(title: "Continue", icon: "arrow.right") { onDone() }
                    } else {
                        PrimaryButton(title: "Open System Settings", icon: "gear") { openAXSettings() }
                        GhostButton(title: "I've granted access", icon: "checkmark") { recheck() }
                    }
                }

                if let msg = checkFailedMessage {
                    Text(msg)
                        .font(FL.T.bodyR())
                        .foregroundStyle(FL.C.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                if !trusted {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Troubleshooting").font(FL.T.title())
                            stepRow(1, "Open System Settings → Privacy & Security → Accessibility")
                            stepRow(2, "Find FocusLens and click the − button to remove it")
                            stepRow(3, "Click + and add FocusLens.app from /Applications")
                            stepRow(4, "Toggle FocusLens ON in the list")
                        }
                        .padding(FL.S.s4)
                    }
                    .frame(maxWidth: 520)
                }

                Spacer()
            }
            .padding(FL.S.s7)
        }
        .frame(width: 620, height: 760)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                trusted = AXIsProcessTrusted()
                if trusted { timer?.invalidate() }
            }
        }
        .onDisappear { timer?.invalidate() }
        .onChange(of: trusted) { _, newValue in
            if newValue { onDone() }
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(FL.T.caption())
                .frame(width: 22, height: 22)
                .background(Circle().fill(FL.C.accentSoft))
                .foregroundStyle(FL.C.accent)
            Text(text).font(FL.T.body())
            Spacer()
        }
    }

    private func recheck() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let t = AXIsProcessTrustedWithOptions(opts)
        trusted = t
        if t {
            checkFailedMessage = nil
            onDone()
        } else {
            checkFailedMessage = "macOS still reports access not granted. Remove FocusLens from the Accessibility list and add it again, then click below."
        }
    }

    private func openAXSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
