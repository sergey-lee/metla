import AppKit

/// Which applications were running when a scan started. Their caches are not preselected.
struct RunningSnapshot: Sendable {
    let bundleIDs: Set<String>
    let names: Set<String>

    static let empty = RunningSnapshot(bundleIDs: [], names: [])

    @MainActor
    static func capture() -> RunningSnapshot {
        let apps = NSWorkspace.shared.runningApplications
        return RunningSnapshot(
            bundleIDs: Set(apps.compactMap { $0.bundleIdentifier?.lowercased() }),
            names: Set(apps.compactMap(\.localizedName).map(NameNormalizer.normalize).filter { $0.count >= 3 })
        )
    }

    /// Whether a Library folder or file name appears to belong to a running application.
    func owns(_ entryName: String) -> Bool {
        let lowered = entryName.lowercased()
        if bundleIDs.contains(where: { $0 == lowered || $0.hasPrefix(lowered + ".") || lowered.hasPrefix($0 + ".") }) {
            return true
        }
        let plain = NameNormalizer.normalize(entryName)
        guard plain.count >= 4 else { return names.contains(plain) }
        return names.contains { $0 == plain || $0.contains(plain) || ($0.count >= 4 && plain.contains($0)) }
    }
}
