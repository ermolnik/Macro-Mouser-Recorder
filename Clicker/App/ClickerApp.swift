import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Clicker") {
            ContentView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
    }
}
