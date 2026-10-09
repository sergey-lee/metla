import AppKit

/// Renders every section of the window to PNG files. Used to check the interface without a person at the screen.
@MainActor
enum SnapshotRunner {
    static func run(app: AppModel, folder: URL, windowSize: CGSize?) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(1))
        if let windowSize, let window = NSApp.windows.first(where: { $0.isVisible }) {
            // Prefer a Retina screen so the pictures come out at full resolution.
            let screen = NSScreen.screens.max { $0.backingScaleFactor < $1.backingScaleFactor } ?? window.screen
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: windowSize))
            if let visible = screen?.visibleFrame {
                frame.origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
            }
            window.setFrame(frame, display: true)
            try? await Task.sleep(for: .milliseconds(500))
        }
        await capture("0-idle", folder)

        app.scanAll()
        for model in app.scans.values {
            await model.waitUntilFinished()
        }
        await app.refreshSystemFacts()
        await app.apps.load()

        for (index, kind) in SectionKind.allCases.enumerated() {
            app.section = kind
            try? await Task.sleep(for: .milliseconds(900))
            await capture("\(index + 1)-\(kind.rawValue)", folder)
        }

        // With a fixture home, also exercise the removal path: trash the extra duplicate copies.
        if !app.environment.isRealHome, CommandLine.arguments.contains("--exercise-trash"), let duplicates = app.scans[.duplicates] {
            app.section = .duplicates
            duplicates.selectExtraCopies()
            try? await Task.sleep(for: .milliseconds(900))
            await capture("8-duplicates-selected", folder)
            await duplicates.trashSelected()
            try? await Task.sleep(for: .milliseconds(900))
            await capture("9-duplicates-trashed", folder)
        }
        NSApp.terminate(nil)
    }

    private static func capture(_ name: String, _ folder: URL) async {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else { return }
        if Sandbox.isActive {
            // The sandbox cannot run screencapture; announce the moment and let the caller take the picture.
            print("SHOT \(window.windowNumber) \(name)")
            fflush(stdout)
            try? await Task.sleep(for: .milliseconds(1500))
        } else {
            _ = Shell.run("/usr/sbin/screencapture", [
                "-x", "-o", "-l", String(window.windowNumber), folder.appending(path: "\(name).png").path
            ])
        }
    }
}
