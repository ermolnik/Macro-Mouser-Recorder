import AppKit
import ApplicationServices

public enum AccessibilityCheck {
    public static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
