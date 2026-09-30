import SwiftUI
import TimetrackerCore

struct ContentView: View {
    @EnvironmentObject private var store: EntryStore
    @ObservedObject private var timerManager = TimerManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var glassNamespace
    @FocusState private var noteFieldFocused: Bool

    @State private var note = ""
    @State private var isPresented = false

    private static let openCurve = Animation.spring(response: 0.28, dampingFraction: 0.88)

    private var time: String { timerManager.formattedTime }
    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSave: Bool { !trimmedNote.isEmpty }

    /// Nil animations are how SwiftUI expresses "no motion".
    private var stateChange: Animation? { reduceMotion ? nil : .bouncy }
    private var openAnimation: Animation? { reduceMotion ? nil : Self.openCurve }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 14) {
                header
                clock

                if timerManager.isLogging {
                    loggingForm
                } else {
                    status
                    controls
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .animation(stateChange, value: timerManager.isLogging)
        }
        .frame(minWidth: 300, minHeight: 210, alignment: .top)
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(isPresented ? 1 : 0.94, anchor: .top)
        .offset(y: isPresented ? 0 : -8)
        .background(WindowAccessor())
        .onAppear {
            withAnimation(openAnimation) { isPresented = true }
            noteFieldFocused = timerManager.isLogging
        }
        .onDisappear {
            isPresented = false
        }
        .onChange(of: timerManager.isLogging) { _, isLogging in
            noteFieldFocused = isLogging
        }
    }

    private var header: some View {
        Text("TimeTracker")
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clock: some View {
        Text(time)
            .font(.system(size: 34, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(timerManager.isLogging ? .secondary : .primary)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: time)
            .padding(.vertical, 12)
            .padding(.horizontal, 26)
            .glassEffect(.regular, in: .capsule)
            .glassEffectID("clock", in: glassNamespace)
    }

    private var status: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(timerManager.isRunning ? .green : .secondary)
                .symbolEffect(.pulse, isActive: timerManager.isRunning && !reduceMotion)

            Text(timerManager.isRunning ? "Tracking in background" : "Press start to begin")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .animation(reduceMotion ? nil : .smooth, value: timerManager.isRunning)
        .transition(.opacity)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if timerManager.isRunning {
                Button {
                    withAnimation(stateChange) { timerManager.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .glassEffectID("primary", in: glassNamespace)
            } else {
                Button {
                    withAnimation(stateChange) { timerManager.start() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .glassEffectID("primary", in: glassNamespace)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .animation(stateChange, value: timerManager.isRunning)
        .transition(.opacity)
    }

    private var loggingForm: some View {
        VStack(spacing: 12) {
            if let range = timerManager.pendingRange {
                Text(rangeSummary(from: range.start, to: range.end))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("What did you work on?", text: $note)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($noteFieldFocused)
                .submitLabel(.done)
                .onSubmit(save)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .glassEffect(.regular, in: .capsule)
                .glassEffectID("note", in: glassNamespace)
                .glassEffectTransition(.materialize)

            HStack(spacing: 10) {
                Button {
                    discard()
                } label: {
                    Label("Discard", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .glassEffectID("secondary", in: glassNamespace)
                .glassEffectTransition(.materialize)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentColor)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
                .glassEffectID("primary", in: glassNamespace)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .animation(stateChange, value: canSave)

            if let message = store.lastErrorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .transition(
            reduceMotion
                ? AnyTransition.opacity
                : AnyTransition.opacity.combined(with: .scale(scale: 0.96, anchor: .top))
        )
    }

    private func save() {
        guard canSave, let entry = timerManager.makeEntry(note: trimmedNote) else { return }

        do {
            try store.add(entry)
        } catch {
            return
        }

        withAnimation(stateChange) {
            note = ""
            timerManager.finishLogging()
        }
    }

    private func discard() {
        withAnimation(stateChange) {
            note = ""
            timerManager.discard()
        }
    }


    private func rangeSummary(from start: Date, to end: Date) -> String {
        let clock = DurationFormat.clock(end.timeIntervalSince(start))
        let from = start.formatted(date: .omitted, time: .shortened)
        let to = end.formatted(date: .omitted, time: .shortened)
        return "\(clock) · \(from) – \(to)"
    }
}
