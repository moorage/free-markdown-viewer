import SwiftUI
#if os(macOS)
import AppKit

struct MacSidebarKeyEventBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onQuickFilter: () -> Void
    let onToggleFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            onQuickFilter: onQuickFilter,
            onToggleFocus: onToggleFocus
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
        context.coordinator.onQuickFilter = onQuickFilter
        context.coordinator.onToggleFocus = onToggleFocus
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var isEnabled = false
        var onMoveUp: () -> Void
        var onMoveDown: () -> Void
        var onQuickFilter: () -> Void
        var onToggleFocus: () -> Void
        private var monitor: Any?

        init(
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void,
            onQuickFilter: @escaping () -> Void,
            onToggleFocus: @escaping () -> Void
        ) {
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
            self.onQuickFilter = onQuickFilter
            self.onToggleFocus = onToggleFocus
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled else { return event }
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers?.lowercased() == "f" {
                    self.onQuickFilter()
                    return nil
                }
                if event.keyCode == 48 {
                    self.onToggleFocus()
                    return nil
                }
                switch event.keyCode {
                case 125:
                    self.onMoveDown()
                    return nil
                case 126:
                    self.onMoveUp()
                    return nil
                default:
                    return event
                }
            }
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        deinit {
            removeMonitor()
        }
    }
}
#endif
