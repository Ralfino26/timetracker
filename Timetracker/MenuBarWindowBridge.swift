import AppKit
import SwiftUI

/// Bridges the SwiftUI content of the menu bar panel to its hosting `NSWindow` so the
/// panel can fade out the way system menus do, and so it tracks the content height
/// when Pause / Done / logging form change the layout.
struct WindowAccessor: NSViewRepresentable {
    var contentWidth: CGFloat = 300

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = FittingView()
        view.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.resizeIfNeeded()
        }
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.contentWidth = contentWidth
        context.coordinator.attach(to: view.window)
        DispatchQueue.main.async {
            context.coordinator.resizeIfNeeded()
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Reports layout changes so the panel can shrink when content gets shorter.
    private final class FittingView: NSView {
        var onLayout: (() -> Void)?

        override func layout() {
            super.layout()
            onLayout?()
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        var contentWidth: CGFloat = 300

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
            guard let window, let contentView = window.contentView else { return }

            let fitting = contentView.fittingSize
            guard fitting.width.isFinite, fitting.height.isFinite,
                  fitting.width > 0, fitting.height > 0
            else { return }

            let target = NSSize(
                width: max(contentWidth, fitting.width),
                height: fitting.height
            )

            let current = window.contentLayoutRect.size
            guard abs(current.width - target.width) > 0.5
                    || abs(current.height - target.height) > 0.5
            else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
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
