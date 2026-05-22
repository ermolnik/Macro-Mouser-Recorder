import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Accessibility permission required")
                .font(.title2).bold()
            Text("Clicker needs Accessibility access to record and replay input events. Open System Settings, then enable Clicker under Privacy & Security → Accessibility.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack {
                Button("Open System Settings") { AccessibilityCheck.openSettings() }
                Button("Re-check") { state.refreshAccessibility() }
            }
        }
        .padding(40)
    }
}
