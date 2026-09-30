import Combine
import Foundation

public enum EntryStoreError: Error, Equatable, Sendable {
    case emptyNote
    case entryNotFound
}

/// Persists `WorkEntry` values as a JSON array and keeps the in-memory list sorted
/// newest first. Writes are atomic, so a crash mid-write cannot truncate the file.
@MainActor
public final class EntryStore: ObservableObject {
    /// Newest first.
    @Published public private(set) var entries: [WorkEntry] = []

    /// Set when a write fails; the UI can surface it without the call site throwing.
    @Published public private(set) var lastErrorMessage: String?

    public let fileURL: URL

    private let directoryURL: URL
    private let calendar: Calendar
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil, calendar: Calendar = .autoupdatingCurrent) {
        directoryURL = directory ?? Self.defaultDirectory()
        fileURL = directoryURL.appendingPathComponent("entries.json", isDirectory: false)
        self.calendar = calendar

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    /// `Application Support/TimeTracker`, or `TIMETRACKER_DATA_DIR` when set.
    public nonisolated static func defaultDirectory() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["TIMETRACKER_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base.appendingPathComponent("TimeTracker", isDirectory: true)
    }

    // MARK: - Mutations

    @discardableResult
    public func add(_ entry: WorkEntry) throws -> WorkEntry {
        let trimmed = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntryStoreError.emptyNote }

        var stored = entry
        stored.note = trimmed
        entries.append(stored)
        sort()
        persist()
        return stored
    }

    @discardableResult
    public func add(startDate: Date, endDate: Date, note: String) throws -> WorkEntry {
        try add(WorkEntry(startDate: startDate, endDate: endDate, note: note))
    }

    public func updateNote(_ note: String, for id: WorkEntry.ID) throws {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntryStoreError.emptyNote }
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw EntryStoreError.entryNotFound
        }
        guard entries[index].note != trimmed else { return }

        entries[index].note = trimmed
        persist()
    }

    public func delete(_ ids: some Sequence<WorkEntry.ID>) {
        let removals = Set(ids)
        guard !removals.isEmpty else { return }

        let remaining = entries.filter { !removals.contains($0.id) }
        guard remaining.count != entries.count else { return }

        entries = remaining
        persist()
    }

    public func delete(_ id: WorkEntry.ID) {
        delete([id])
    }

    // MARK: - Queries

    public func entry(with id: WorkEntry.ID) -> WorkEntry? {
        entries.first { $0.id == id }
    }

    /// Entries that started on the given day, oldest first — reading a day top to bottom.
    public func entries(on day: Date) -> [WorkEntry] {
        entries
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    public func totalDuration(on day: Date) -> TimeInterval {
        entries(on: day).reduce(0) { $0 + $1.duration }
    }

    public func hasEntries(on day: Date) -> Bool {
        entries.contains { calendar.isDate($0.startDate, inSameDayAs: day) }
    }

    /// Start-of-day dates inside the month containing `month` that hold at least one entry.
    public func daysWithEntries(in month: Date) -> Set<Date> {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }

        return Set(
            entries
                .filter { interval.contains($0.startDate) }
                .map { calendar.startOfDay(for: $0.startDate) }
        )
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            entries = []
            return
        }

        do {
            entries = try decoder.decode([WorkEntry].self, from: data)
            sort()
        } catch {
            // Unreadable file: start empty rather than refusing to launch.
            entries = []
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func sort() {
        entries.sort { $0.startDate > $1.startDate }
    }
}
