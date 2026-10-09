import Darwin
import Foundation

/// Low-level facts about a file that `URLResourceValues` does not expose.
struct FileIdentity: Hashable, Sendable {
    let device: Int32
    let inode: UInt64
    /// The content lives in the cloud only; reading it would trigger a download.
    let isDataless: Bool

    init?(path: String) {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        device = info.st_dev
        inode = info.st_ino
        isDataless = (info.st_flags & UInt32(SF_DATALESS)) != 0
    }
}
