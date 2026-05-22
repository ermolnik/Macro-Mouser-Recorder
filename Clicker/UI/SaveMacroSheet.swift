import SwiftUI

struct SaveMacroSheet: View {
    @EnvironmentObject var state: AppState
    @Binding var isPresented: Bool
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save macro").font(.title3).bold()
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") {
                    state.saveCurrent(as: name.isEmpty ? "Untitled" : name)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(state.currentEvents.isEmpty)
            }
        }
        .padding(20)
    }
}
