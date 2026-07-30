import SwiftUI
import AppKit

/// Takes window-frame persistence away from AppKit's automatic autosave.
///
/// SwiftUI's window subclass re-persists the frame from `_persistFrame` on
/// *every* window-move event the window server delivers. Each of those does a
/// synchronous `UserDefaults` read *and* write on the main thread, and the write
/// invalidates the CFPreferences cache so the following read has to re-merge the
/// whole search list. Sampling a drag showed 208 of 211 samples in the move path
/// sitting in exactly that — dragging the window was mostly preference I/O.
///
/// So: inherit whatever autosave name SwiftUI generated (keeping the stored
/// frame and the restore-on-launch behaviour identical), switch autosaving off,
/// and write the frame ourselves — coalesced after the user stops moving, and
/// again on close/quit.
@MainActor
final class WindowFrameCoordinator {
    static let shared = WindowFrameCoordinator()

    /// Long enough that a drag or resize writes once at the end rather than once
    /// per frame, short enough that a force-quit rarely loses the frame.
    private static let debounce: TimeInterval = 0.75

    private var names: [ObjectIdentifier: NSWindow.FrameAutosaveName] = [:]
    private var pendingSaves: [ObjectIdentifier: DispatchWorkItem] = [:]

    private init() {}

    /// Idempotent: safe to call again for a window we already manage, which
    /// matters because SwiftUI can rebuild the representable that installs us.
    func adopt(_ window: NSWindow) {
        let key = ObjectIdentifier(window)
        guard names[key] == nil else { return }

        // SwiftUI has already restored the frame under this name; reusing it
        // means the on-disk key and the restore path are unchanged.
        let inherited = window.frameAutosaveName
        guard !inherited.isEmpty else { return }
        names[key] = inherited
        window.setFrameAutosaveName("")

        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            center.addObserver(forName: name, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated {
                    guard let window else { return }
                    WindowFrameCoordinator.shared.scheduleSave(for: window)
                }
            }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak window] _ in
            MainActor.assumeIsolated {
                guard let window else { return }
                WindowFrameCoordinator.shared.save(window)
                WindowFrameCoordinator.shared.forget(window)
            }
        }
        center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak window] _ in
            MainActor.assumeIsolated {
                guard let window else { return }
                WindowFrameCoordinator.shared.save(window)
            }
        }
    }

    private func scheduleSave(for window: NSWindow) {
        let key = ObjectIdentifier(window)
        pendingSaves[key]?.cancel()
        let work = DispatchWorkItem { [weak window] in
            MainActor.assumeIsolated {
                guard let window else { return }
                WindowFrameCoordinator.shared.save(window)
            }
        }
        pendingSaves[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    private func save(_ window: NSWindow) {
        let key = ObjectIdentifier(window)
        pendingSaves[key]?.cancel()
        pendingSaves[key] = nil
        guard let name = names[key] else { return }
        window.saveFrame(usingName: name)
    }

    private func forget(_ window: NSWindow) {
        let key = ObjectIdentifier(window)
        pendingSaves[key]?.cancel()
        pendingSaves[key] = nil
        names[key] = nil
    }
}

/// Installs ``WindowFrameCoordinator`` on the window hosting this view.
private struct WindowFramePersistence: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The view isn't in a window yet during `makeNSView`.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            WindowFrameCoordinator.shared.adopt(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func persistsWindowFrameEfficiently() -> some View {
        background(WindowFramePersistence().frame(width: 0, height: 0))
    }
}
