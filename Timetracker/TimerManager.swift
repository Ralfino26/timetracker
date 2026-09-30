import Foundation
import Combine

class TimerManager: ObservableObject, Identifiable {
    static let shared = TimerManager()

    let id = UUID()
    @Published var isRunning = false
    @Published var elapsedSeconds: TimeInterval = 0

    private var startDate: Date?
    private var accumulatedSeconds: TimeInterval = 0
    private var timer: Timer?

    init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        accumulatedSeconds += elapsedSeconds
        elapsedSeconds = 0
        isRunning = false
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    func reset() {
        stop()
        accumulatedSeconds = 0
        elapsedSeconds = 0
    }

    func formattedTime() -> String {
        let total = Int(accumulatedSeconds + elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func tick() {
        if let startDate = startDate {
            elapsedSeconds = startDate.distance(to: Date())
        }
    }
}
