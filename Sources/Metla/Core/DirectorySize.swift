import Foundation

enum DirectorySize {
    private static let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
    private static let keySet = Set(keys)

    /// Space the file or folder occupies on disk, in bytes.
    static func allocated(_ url: URL) -> Int64 {
        let rootKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let root = try? url.resourceValues(forKeys: rootKeys) else { return 0 }
        if root.isDirectory != true || root.isSymbolicLink == true {
            return Int64(root.totalFileAllocatedSize ?? root.fileSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var counter = 0
        while let file = enumerator.nextObject() as? URL {
            counter += 1
            if counter & 0xFFF == 0, Task.isCancelled { break }
            guard let values = try? file.resourceValues(forKeys: keySet), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }
}
