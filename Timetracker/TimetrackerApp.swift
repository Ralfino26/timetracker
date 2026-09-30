import SwiftUI

@main
struct TimetrackerApp: App {
    @ObservedObject private var timerManager = TimerManager.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: timerManager.isRunning ? "record.circle.fill" : "clock")
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: timerManager.isRunning)
                .contentTransition(.symbolEffect(.replace))
        }
        .menuBarExtraStyle(.window)
    }
}
