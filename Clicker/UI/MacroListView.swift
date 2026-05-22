import SwiftUI

struct MacroListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        List(selection: $state.selectedMacroID) {
            ForEach(state.savedMacros) { macro in
                HStack {
                    VStack(alignment: .leading) {
                        Text(macro.name).font(.headline)
                        Text("\(macro.eventCount) events · \(String(format: "%.1f", macro.durationSeconds))s")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .tag(macro.id)
                .contextMenu {
                    Button("Delete", role: .destructive) { state.delete(macro) }
                }
            }
        }
        .frame(minHeight: 200)
    }
}
