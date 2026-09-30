import SwiftUI
import TimetrackerCore

@main
struct TimetrackerApp: App {
    @ObservedObject private var timerManager = TimerManager.shared
    @StateObject private var store = EntryStore()

    private var menuBarSymbol: String {
        if timerManager.isLogging { return "pencil.circle.fill" }
        if timerManager.isRunning { return "record.circle.fill" }
        return "clock"
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            Image(systemName: menuBarSymbol)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: timerManager.isRunning)
                .contentTransition(.symbolEffect(.replace))
        }
        .menuBarExtraStyle(.window)

        Window("History", id: "history") {
            HistoryView()
                .environmentObject(store)
        }
        .defaultSize(width: 820, height: 520)
        .windowResizability(.contentMinSize)
    }
}
