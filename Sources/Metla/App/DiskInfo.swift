import Foundation

struct DiskInfo: Sendable {
    let name: String
    let total: Int64
    let available: Int64

    var used: Int64 { total - available }

    static func current() -> DiskInfo? {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]
        // Volume figures are cached per URL value; drop the cache so every call reads fresh numbers.
        var home = URL.homeDirectory
        home.removeAllCachedResourceValues()
        guard let values = try? home.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskInfo(name: values.volumeName ?? String(localized: "Диск"), total: Int64(total), available: available)
    }
}
