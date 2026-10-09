import CryptoKit
import Foundation

enum FileHasher {
    private static let sampleLength = 16 * 1024
    private static let chunkLength = 1024 * 1024

    /// Files up to this size are fully covered by `sampleHash`.
    static let sampleCoversUpTo = Int64(sampleLength * 3)

    /// Hash of the first, middle and last blocks. Cheap way to rule out most non-duplicates.
    static func sampleHash(_ url: URL, size: Int64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            if size <= sampleCoversUpTo {
                guard let data = try handle.readToEnd() else { return nil }
                hasher.update(data: data)
            } else {
                let offsets: [UInt64] = [0, UInt64(size) / 2, UInt64(size) - UInt64(sampleLength)]
                for offset in offsets {
                    try handle.seek(toOffset: offset)
                    guard let data = try handle.read(upToCount: sampleLength) else { return nil }
                    hasher.update(data: data)
                }
            }
        } catch {
            return nil
        }
        return Data(hasher.finalize())
    }

    /// Hash of the whole file, read in chunks without filling the system file cache.
    static func fullHash(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        _ = fcntl(handle.fileDescriptor, F_NOCACHE, 1)
        var hasher = SHA256()
        do {
            while true {
                if Task.isCancelled { return nil }
                guard let data = try handle.read(upToCount: chunkLength), !data.isEmpty else { break }
                hasher.update(data: data)
            }
        } catch {
            return nil
        }
        return Data(hasher.finalize())
    }
}
