import Foundation

/// Text mode: `Metla --cli junk|duplicates|large|old|leftovers|apps [--home dir] [--root dir]`.
/// Prints what a scan finds without touching anything.
enum CommandLineTool {
    @MainActor
    static func run(_ arguments: [String]) {
        let running = RunningSnapshot.capture()
        let options = LaunchOptions(arguments: arguments)
        Task {
            await execute(arguments, options: options, running: running)
            exit(0)
        }
        RunLoop.main.run()
    }

    @concurrent
    private static func execute(_ arguments: [String], options: LaunchOptions, running: RunningSnapshot) async {
        let env = options.environment
        var settings = ScanSettings.current
        if let root = options.root {
            settings.root = root
        }
        let progress = ProgressSink.silent
        let started = Date.now

        let groups: [ItemGroup]
        switch arguments.first {
        case "junk":
            groups = await JunkScanner.scan(env: env, running: running, progress: progress)
        case "duplicates":
            groups = await DuplicateScanner.scan(root: settings.root, env: env, minSize: settings.duplicateMinSize, progress: progress)
        case "large":
            groups = await LargeFileScanner.scan(
                root: settings.root, env: env, minSize: settings.largeMinSize,
                includeLibrary: settings.largeIncludeLibrary, progress: progress
            )
        case "old":
            groups = await OldFileScanner.scan(
                root: settings.root, env: env, months: settings.oldMonths, minSize: settings.oldMinSize, progress: progress
            )
        case "leftovers":
            groups = await LeftoverScanner.scan(env: env, running: running, progress: progress)
        case "apps":
            for app in InstalledApps.userApps(env: env) {
                print("\(app.name)\t\(app.bundleID)\thelpers: \(app.helperIDs.count)")
            }
            return
        case "check-protected":
            // Prints whether the removal guard would refuse each path. Removes nothing.
            for path in arguments.dropFirst().filter({ $0.hasPrefix("/") }) {
                print("\(Trasher.isProtected(URL(filePath: path)) ? "PROTECTED" : "allowed  ")\t\(path)")
            }
            return
        case "trash-test":
            // Moves the given paths to the Trash; used to verify the removal path on fixtures.
            let outcome = await Trasher.trash(arguments.dropFirst().filter { $0.hasPrefix("/") }.map { URL(filePath: $0) })
            print("trashed: \(outcome.trashed.sorted())")
            print("failures: \(outcome.failures.map { "\($0.path): \($0.reason)" })")
            return
        default:
            print("usage: Metla --cli junk|duplicates|large|old|leftovers|apps [--home dir] [--root dir]")
            return
        }

        let limit = arguments.contains("--all") ? Int.max : 8
        for group in groups {
            print("\n■ \(group.title) — \(Fmt.bytes(group.totalSize)), \(group.items.count) items")
            if let subtitle = group.subtitle {
                print("  \(subtitle)")
            }
            for item in group.items.prefix(limit) {
                let mark = item.preselected ? "[x]" : "[ ]"
                print("  \(mark) \(Fmt.bytes(item.size))\t\(item.title)\t\(Fmt.tilde(item.url.path))\t\(item.note ?? "")")
            }
            if group.items.count > limit {
                print("  … \(group.items.count - limit) more")
            }
        }
        let total = groups.reduce(Int64(0)) { $0 + $1.totalSize }
        let seconds = Date.now.timeIntervalSince(started).formatted(.number.precision(.fractionLength(1)))
        print("\nTotal: \(Fmt.bytes(total)), groups: \(groups.count), time: \(seconds) s")
    }
}
