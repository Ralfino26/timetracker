import AppKit
import SwiftUI

/// Bridges the SwiftUI content of the menu bar panel to its hosting `NSWindow` so the
/// panel can fade out the way system menus do. `MenuBarExtra` orders its window out
/// immediately on resign-key, so the dismissal has to be driven from AppKit.
struct WindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.attach(to: view.window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []

        func attach(to window: NSWindow?) {
            guard let window, window !== self.window else { return }
            detach()
            self.window = window

            window.isOpaque = false
            window.backgroundColor = .clear
            window.animationBehavior = .utilityWindow
            resetAlpha()

            let center = NotificationCenter.default
            observers = [
                center.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.resetAlpha()
                },
                center.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.fadeOut()
                },
            ]
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            window = nil
        }

        private func fadeOut() {
            guard let window, window.alphaValue > 0 else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0
            }
        }

        /// Cancels any in-flight fade so a re-opened panel starts fully visible.
        private func resetAlpha() {
            guard let window else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                window.animator().alphaValue = 1
            }
        }
    }
}
