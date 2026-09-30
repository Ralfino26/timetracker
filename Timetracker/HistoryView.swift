import SwiftUI
import TimetrackerCore

struct HistoryView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var visibleMonth = Calendar.current.startOfDay(for: Date())
    @State private var selection: Set<WorkEntry.ID> = []
    @State private var pendingDeletion: Set<WorkEntry.ID> = []

    private var dayEntries: [WorkEntry] { store.entries(on: selectedDay) }

    var body: some View {
        NavigationSplitView {
            MonthCalendarView(month: $visibleMonth, selectedDay: $selectedDay)
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 340)
        } detail: {
            detail
        }
        .navigationTitle("History")
        .onChange(of: selectedDay) { _, _ in
            selection = []
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { !pendingDeletion.isEmpty },
                set: { if !$0 { pendingDeletion = [] } }
            )
        ) {
            Button("Delete", role: .destructive) {
                store.delete(pendingDeletion)
                selection.subtract(pendingDeletion)
                pendingDeletion = []
            }
            Button("Cancel", role: .cancel) { pendingDeletion = [] }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeader
            Divider()

            if dayEntries.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    pendingDeletion = selection
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
                .help("Delete selected entries")
            }
        }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.title3.weight(.semibold))

                Text(
                    dayEntries.isEmpty
                        ? "No entries"
                        : "\(dayEntries.count) \(dayEntries.count == 1 ? "entry" : "entries")"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(DurationFormat.compact(store.totalDuration(on: selectedDay)))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(16)
        .animation(reduceMotion ? nil : .smooth, value: dayEntries)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing tracked",
            systemImage: "clock.badge.questionmark",
            description: Text("Start the timer from the menu bar to log time for this day.")
        )
        .frame(maxHeight: .infinity)
    }

    private var table: some View {
        Table(dayEntries, selection: $selection) {
            TableColumn("Start") { entry in
                Text(entry.startDate, format: .dateTime.hour().minute())
                    .monospacedDigit()
            }
            .width(min: 64, ideal: 72)

            TableColumn("End") { entry in
                Text(entry.endDate, format: .dateTime.hour().minute())
                    .monospacedDigit()
            }
            .width(min: 64, ideal: 72)

            TableColumn("Duration") { entry in
                Text(entry.formattedDuration)
                    .monospacedDigit()
            }
            .width(min: 76, ideal: 88)

            TableColumn("Note") { entry in
                NoteCell(entry: entry) { note in
                    (try? store.updateNote(note, for: entry.id)) != nil
                }
            }
        }
        .contextMenu(forSelectionType: WorkEntry.ID.self) { ids in
            Button("Delete", role: .destructive) {
                pendingDeletion = ids.isEmpty ? selection : ids
            }
            .disabled(ids.isEmpty && selection.isEmpty)
        }
        .onDeleteCommand {
            guard !selection.isEmpty else { return }
            pendingDeletion = selection
        }
    }

    private var deletionTitle: String {
        pendingDeletion.count == 1
            ? "Delete this entry?"
            : "Delete \(pendingDeletion.count) entries?"
    }
}

/// Inline note editor. Commits on Return or when focus leaves, and snaps back when the
/// store rejects the value (a note can never be blank).
private struct NoteCell: View {
    let entry: WorkEntry
    let commit: (String) -> Bool

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Note", text: $draft)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onAppear { draft = entry.note }
            .onChange(of: entry.note) { _, note in
                guard !isFocused else { return }
                draft = note
            }
            .onSubmit { commitDraft() }
            .onChange(of: isFocused) { _, focused in
                guard !focused else { return }
                commitDraft()
            }
    }

    private func commitDraft() {
        guard draft != entry.note else { return }
        if !commit(draft) {
            draft = entry.note
        }
    }
}
