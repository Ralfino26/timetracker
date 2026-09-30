import AppKit
import SwiftUI

/// Bridges the SwiftUI content of the menu bar panel to its hosting `NSWindow` so the
/// panel can fade out the way system menus do, and so it grows when the logging form
/// appears. `MenuBarExtra` often keeps its first content size unless AppKit is told.
struct WindowAccessor: NSViewRepresentable {
    var contentHeight: CGFloat = 210
    var contentWidth: CGFloat = 300

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.contentWidth = contentWidth
        context.coordinator.contentHeight = contentHeight
        context.coordinator.attach(to: view.window)
        context.coordinator.resizeIfNeeded()
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        var contentWidth: CGFloat = 300
        var contentHeight: CGFloat = 210

        func attach(to window: NSWindow?) {
            guard let window else { return }
            if window !== self.window {
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
            resizeIfNeeded()
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            window = nil
        }

        func resizeIfNeeded() {
            guard let window else { return }

            var target = NSSize(width: contentWidth, height: contentHeight)
            if let contentView = window.contentView {
                let fitting = contentView.fittingSize
                if fitting.width.isFinite, fitting.width > 0 {
                    target.width = max(contentWidth, fitting.width)
                }
                if fitting.height.isFinite, fitting.height > 0 {
                    target.height = max(contentHeight, fitting.height)
                }
            }

            let current = window.contentLayoutRect.size
            guard abs(current.width - target.width) > 0.5
                    || abs(current.height - target.height) > 0.5
            else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setContentSize(target)
            }
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
