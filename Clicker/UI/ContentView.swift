import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showingSaveSheet = false

    var body: some View {
        Group {
            if state.hasAccessibility {
                main
            } else {
                PermissionsView()
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { state.refreshAccessibility() }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusBar
            recordRow
            Divider()
            PlaybackControlsView()
            Divider()
            Text("Saved macros").font(.headline)
            MacroListView()
            HStack {
                Spacer()
                Text("Stop hotkey: F8").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .sheet(isPresented: $showingSaveSheet) {
            SaveMacroSheet(isPresented: $showingSaveSheet)
        }
    }

    private var statusBar: some View {
        HStack {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.headline)
            Spacer()
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .idle: return .gray
        case .recording: return .red
        case .playing: return .green
        }
    }

    private var statusText: String {
        switch state.status {
        case .idle: return "Idle"
        case .recording: return "Recording…"
        case .playing(let i, let total):
            if let t = total { return "Playing \(i)/\(t)" }
            return "Playing (∞)"
        }
    }

    private var recordRow: some View {
        HStack(spacing: 12) {
            switch state.status {
            case .recording:
                Button("Stop recording") { state.stopRecording() }
                    .keyboardShortcut(.return)
            default:
                Button("Record") { state.startRecording() }
                    .disabled(state.status != .idle)
            }

            Button("Play") {
                if let id = state.selectedMacroID,
                   let macro = state.savedMacros.first(where: { $0.id == id }) {
                    state.startPlayback(events: macro.events)
                } else if !state.currentEvents.isEmpty {
                    state.startPlayback(events: state.currentEvents)
                }
            }
            .disabled(state.status != .idle ||
                      (state.currentEvents.isEmpty && state.selectedMacroID == nil))

            Button("Stop") { state.requestStop() }
                .disabled({ if case .playing = state.status { return false }; return true }())

            Spacer()

            Button("Save current…") { showingSaveSheet = true }
                .disabled(state.currentEvents.isEmpty || state.status != .idle)
        }
    }
}
