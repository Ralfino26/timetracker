import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @Namespace private var glassNamespace
    @State private var isPresented = false

    private static let openCurve = Animation.spring(response: 0.28, dampingFraction: 0.88)

    private var time: String { timerManager.formattedTime() }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 16) {
                header
                clock
                status
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(minWidth: 260, minHeight: 210, alignment: .top)
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(isPresented ? 1 : 0.94, anchor: .top)
        .offset(y: isPresented ? 0 : -8)
        .background(WindowAccessor())
        .onAppear {
            withAnimation(Self.openCurve) { isPresented = true }
        }
        .onDisappear {
            isPresented = false
        }
    }

    private var header: some View {
        Text("TimeTracker")
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private var clock: some View {
        Text(time)
            .font(.system(size: 34, weight: .medium, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.25), value: time)
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
                .symbolEffect(.pulse, isActive: timerManager.isRunning)

            Text(timerManager.isRunning ? "Tracking in background" : "Press start to begin")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .animation(.smooth, value: timerManager.isRunning)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if timerManager.isRunning {
                Button {
                    withAnimation(.bouncy) { timerManager.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .glassEffectID("primary", in: glassNamespace)
            } else {
                Button {
                    withAnimation(.bouncy) { timerManager.start() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .glassEffectID("primary", in: glassNamespace)

                Button {
                    withAnimation(.bouncy) { timerManager.reset() }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .glassEffectID("secondary", in: glassNamespace)
                .glassEffectTransition(.materialize)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .animation(.bouncy, value: timerManager.isRunning)
    }
}
