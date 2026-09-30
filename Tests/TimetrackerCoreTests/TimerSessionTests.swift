import Foundation
import Testing
@testable import TimetrackerCore

@Suite("TimerSession")
struct TimerSessionTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("A fresh session is idle with a zeroed clock")
    func startsIdle() {
        let session = TimerSession()

        #expect(session.state == .idle)
        #expect(session.isRunning == false)
        #expect(session.isPaused == false)
        #expect(session.isLogging == false)
        #expect(session.pendingRange == nil)
        #expect(session.elapsed(at: start) == 0)
    }

    @Test("Starting moves idle to running and the clock follows the date")
    func startFromIdle() {
        var session = TimerSession()

        #expect(session.start(at: start) == true)
        #expect(session.isRunning == true)
        #expect(session.elapsed(at: start.addingTimeInterval(90)) == 90)
    }

    @Test("Starting twice is ignored and keeps the original start date")
    func startIsIdempotent() {
        var session = TimerSession()
        session.start(at: start)

        #expect(session.start(at: start.addingTimeInterval(60)) == false)
        #expect(session.isRunning == true)
        #expect(session.elapsed(at: start.addingTimeInterval(60)) == 60)
    }

    @Test("Pausing freezes the clock and resume continues from there")
    func pauseAndResume() {
        var session = TimerSession()
        session.start(at: start)
        let pauseAt = start.addingTimeInterval(40)

        #expect(session.pause(at: pauseAt) == true)
        #expect(session.isPaused == true)
        #expect(session.isRunning == false)
        #expect(session.elapsed(at: pauseAt.addingTimeInterval(100)) == 40)

        let resumeAt = pauseAt.addingTimeInterval(20)
        #expect(session.resume(at: resumeAt) == true)
        #expect(session.isRunning == true)
        #expect(session.elapsed(at: resumeAt.addingTimeInterval(15)) == 55)
    }

    @Test("Finish from running opens logging with the full session range")
    func finishFromRunning() {
        var session = TimerSession()
        session.start(at: start)
        let end = start.addingTimeInterval(125)

        #expect(session.finish(at: end) == true)
        #expect(session.state == .logging(start: start, end: end))
        #expect(session.isLogging == true)
        #expect(session.elapsed(at: end.addingTimeInterval(500)) == 125)
    }

    @Test("Finish from paused keeps paused elapsed and original start")
    func finishFromPaused() {
        var session = TimerSession()
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(50))

        #expect(session.finish(at: start.addingTimeInterval(80)) == true)
        #expect(session.pendingRange?.start == start)
        #expect(session.pendingRange?.end == start.addingTimeInterval(50))
        #expect(session.elapsed(at: start) == 50)
    }

    @Test("Pause and finish are ignored in the wrong state")
    func invalidTransitions() {
        var idle = TimerSession()
        #expect(idle.pause(at: start) == false)
        #expect(idle.resume(at: start) == false)
        #expect(idle.finish(at: start) == false)

        var running = TimerSession()
        running.start(at: start)
        #expect(running.resume(at: start) == false)

        var logging = TimerSession()
        logging.start(at: start)
        logging.finish(at: start.addingTimeInterval(10))
        let before = logging.state
        #expect(logging.pause(at: start.addingTimeInterval(20)) == false)
        #expect(logging.finish(at: start.addingTimeInterval(20)) == false)
        #expect(logging.state == before)
    }

    @Test("Starting is ignored while paused or logging")
    func startIgnoredWhileActive() {
        var paused = TimerSession()
        paused.start(at: start)
        paused.pause(at: start.addingTimeInterval(10))
        #expect(paused.start(at: start.addingTimeInterval(20)) == false)
        #expect(paused.isPaused == true)

        var logging = TimerSession()
        logging.start(at: start)
        logging.finish(at: start.addingTimeInterval(10))
        #expect(logging.start(at: start.addingTimeInterval(20)) == false)
        #expect(logging.isLogging == true)
    }

    @Test("Discarding returns to idle from any state")
    func discardReturnsToIdle() {
        var session = TimerSession()
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(30))

        session.discard()

        #expect(session.state == .idle)
        #expect(session.elapsed(at: start.addingTimeInterval(60)) == 0)
    }

    @Test("Logging builds an entry with the pending range and a trimmed note")
    func makeEntryFromLogging() throws {
        var session = TimerSession()
        session.start(at: start)
        let end = start.addingTimeInterval(45)
        session.finish(at: end)

        let entry = try #require(session.makeEntry(note: "  Wrote tests \n"))

        #expect(entry.startDate == start)
        #expect(entry.endDate == end)
        #expect(entry.note == "Wrote tests")
        #expect(entry.duration == 45)
    }

    @Test("No entry without a note or outside the logging state")
    func makeEntryRequiresNoteAndLoggingState() {
        var session = TimerSession()
        #expect(session.makeEntry(note: "Idle work") == nil)

        session.start(at: start)
        #expect(session.makeEntry(note: "Running work") == nil)

        session.pause(at: start.addingTimeInterval(10))
        #expect(session.makeEntry(note: "Paused work") == nil)

        session.finish(at: start.addingTimeInterval(10))
        #expect(session.makeEntry(note: "") == nil)
        #expect(session.makeEntry(note: "   \n\t ") == nil)
        #expect(session.makeEntry(note: "Real work") != nil)
    }

    @Test("A full pause-resume-finish cycle ends back at idle")
    func fullCycle() {
        var session = TimerSession()
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(20))
        session.resume(at: start.addingTimeInterval(30))
        session.finish(at: start.addingTimeInterval(50))
        _ = session.makeEntry(note: "Done")
        session.discard()

        #expect(session.state == .idle)
        #expect(session.start(at: start.addingTimeInterval(120)) == true)
    }
}

@Suite("DurationFormat")
struct DurationFormatTests {
    @Test("Clock strings switch to hours only when needed")
    func clock() {
        #expect(DurationFormat.clock(0) == "00:00")
        #expect(DurationFormat.clock(9) == "00:09")
        #expect(DurationFormat.clock(65) == "01:05")
        #expect(DurationFormat.clock(3599) == "59:59")
        #expect(DurationFormat.clock(3600) == "1:00:00")
        #expect(DurationFormat.clock(7325) == "2:02:05")
        #expect(DurationFormat.clock(-5) == "00:00")
    }

    @Test("Compact strings read like a day total")
    func compact() {
        #expect(DurationFormat.compact(42) == "42s")
        #expect(DurationFormat.compact(900) == "15m")
        #expect(DurationFormat.compact(3600) == "1h")
        #expect(DurationFormat.compact(8100) == "2h 15m")
    }
}
