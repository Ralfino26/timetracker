import SwiftUI

@main
struct TimetrackerApp: App {
    var body: some Scene {
        MenuBarExtra("TimeTracker", systemImage: "clock") {
            Text("TimeTracker")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
