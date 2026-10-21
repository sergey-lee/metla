import Foundation

/// Lists the heaviest files and packages under a folder.
enum LargeFileScanner {
    private static let maxItems = 500
    private static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "xip", "ipsw", "iso"]
    private static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv"]
    private static let libraryExtensions: Set<String> = ["photoslibrary", "musiclibrary", "tvlibrary", "fcpbundle", "imovielibrary"]

    @concurrent
    static func scan(
        root: URL, env: ScanEnvironment, minSize: Int64, includeLibrary: Bool, progress: ProgressSink
    ) async -> [ItemGroup] {
        var options = WalkOptions()
        options.includeHiddenAndLibrary = includeLibrary
        options.skipDeveloperFolders = false
        options.packagesAsItems = true

        let found = await FileWalker.collect(root: root, env: env, options: options, progress: progress) { file in
            file.allocatedSize >= minSize && !AppleData.owns(path: file.url)
        }
        if Task.isCancelled || found.isEmpty { return [] }

        let yearAgo = Date.now.addingTimeInterval(-365 * 86_400)
        let items = found
            .sorted { $0.allocatedSize > $1.allocatedSize }
            .prefix(maxItems)
            .map { file in
                let (safety, note) = advice(for: file, env: env, yearAgo: yearAgo)
                return FoundItem(
                    url: file.url, size: file.allocatedSize, date: file.lastActivity, note: note, safety: safety
                )
            }
        return [ItemGroup(id: "large", title: String(localized: "Большие файлы"), subtitle: nil, symbol: "externaldrive", items: items)]
    }

    private static func advice(for file: WalkedFile, env: ScanEnvironment, yearAgo: Date) -> (Safety, String?) {
        let path = file.url.path
        let ext = file.url.pathExtension.lowercased()
        let relative = path.hasPrefix(env.home.path) ? String(path.dropFirst(env.home.path.count)) : path

        if relative.hasPrefix("/Library/") {
            return (.caution, String(localized: "Внутренние данные приложения — удаление может его сломать"))
        }
        if relative.contains("/.") {
            return (.caution, String(localized: "Лежит в скрытой служебной папке"))
        }
        if libraryExtensions.contains(ext) {
            return (.caution, String(localized: "Медиатека целиком — в ней все ваши фото, музыка или проекты"))
        }
        if file.isPackage, ext == "app" {
            return (.review, String(localized: "Приложение. Удалять лучше через раздел «Приложения» — вместе со связанными файлами"))
        }
        if installerExtensions.contains(ext) {
            return (.review, String(localized: "Установщик или образ диска — после установки больше не нужен"))
        }
        let stale = (file.lastActivity ?? .now) < yearAgo
        if archiveExtensions.contains(ext) {
            return (.review, stale ? String(localized: "Архив, не открывался больше года") : String(localized: "Архив"))
        }
        if videoExtensions.contains(ext) {
            return (.review, stale ? String(localized: "Видео, не открывалось больше года") : String(localized: "Видео"))
        }
        return (.review, stale ? String(localized: "Не использовался больше года") : nil)
    }
}
