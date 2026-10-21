import Foundation

/// Finds files that can be removed without losing user data: caches, logs, old installers and the like.
enum JunkScanner {
    private static let megabyte: Int64 = 1_000_000
    private static let day: TimeInterval = 86_400

    @concurrent
    static func scan(env: ScanEnvironment, running: RunningSnapshot, progress: ProgressSink) async -> [ItemGroup] {
        let index = OwnershipIndex(apps: InstalledApps.allKnown(env: env), running: running)
        let steps: [@Sendable () -> ItemGroup?] = [
            { appCaches(env, running, index) },
            { embeddedCaches(env, running) },
            { logs(env) },
            { xcode(env) },
            { developerCaches(env) },
            { downloads(env) },
            { screenshots(env) },
            { deviceBackups(env) },
            { firmware(env) },
            { mailDownloads(env) }
        ]
        // Sizing big folders dominates the time, so categories run side by side.
        let counter = ProgressCounter(total: steps.count)
        let groups = await parallelMap(steps, limit: 4) { step -> ItemGroup? in
            if Task.isCancelled { return nil }
            let group = step()
            progress.send(String(localized: "Проверено категорий: \(counter.increment()) из \(counter.total)"))
            return group
        }
        if Task.isCancelled { return [] }
        return groups.compactMap { $0.flatMap { $0 } }
    }

    // MARK: - Categories

    /// Note for a package manager cache that is simply downloaded again.
    private static func redownloaded(_ tool: String) -> String {
        String(localized: "Кэш пакетов \(tool) — загрузится заново")
    }

    /// Note for a cache the tool rebuilds locally.
    private static func rebuilt(_ tool: String) -> String {
        String(localized: "Кэш \(tool) — создаётся заново автоматически")
    }

    private static let cacheNotes: [String: (Safety, String)] = [
        "ms-playwright": (.review, String(localized: "Браузеры Playwright. После удаления потребуется снова выполнить playwright install")),
        "Homebrew": (.safe, redownloaded("Homebrew")),
        "pip": (.safe, redownloaded("pip")),
        "Yarn": (.safe, redownloaded("Yarn")),
        "CocoaPods": (.safe, redownloaded("CocoaPods")),
        "org.swift.swiftpm": (.safe, redownloaded("Swift Package Manager")),
        "node-gyp": (.safe, redownloaded("node-gyp")),
        "electron": (.safe, redownloaded("Electron")),
        "go-build": (.safe, rebuilt("Go"))
    ]

    private static func appCaches(_ env: ScanEnvironment, _ running: RunningSnapshot, _ index: OwnershipIndex) -> ItemGroup? {
        let items = children(env.library.appending(path: "Caches")).compactMap { url -> FoundItem? in
            let name = url.lastPathComponent
            // Apple's caches, Xcode's included, can hold sign-in state and are never offered.
            if AppleData.owns(name: name) { return nil }
            // A folder with a plain name is listed only when it belongs to an installed app or a known
            // tool, so unknown system folders are left alone.
            if !LibraryCatalog.looksLikeIdentifier(name), cacheNotes[name] == nil,
               !index.ownsName(NameNormalizer.normalize(name)) {
                return nil
            }
            let size = DirectorySize.allocated(url)
            guard size >= megabyte else { return nil }
            if running.owns(name) {
                return FoundItem(
                    url: url, size: size, date: modified(url),
                    note: String(localized: "Приложение сейчас запущено — закройте его перед очисткой"),
                    safety: .review
                )
            }
            let (safety, note) = cacheNotes[name] ?? (.safe, String(localized: "Кэш — приложение создаст его заново"))
            return FoundItem(url: url, size: size, date: modified(url), note: note, safety: safety, preselected: safety == .safe)
        }
        return group(
            id: "caches", title: String(localized: "Кэши приложений"),
            subtitle: String(localized: "Временные файлы. Приложения создают их заново, первое открытие может быть чуть медленнее."),
            symbol: "internaldrive", items: items
        )
    }

    private static let embeddedCacheNames = [
        "Cache", "Code Cache", "GPUCache", "CachedData", "CachedExtensionVSIXs", "DawnCache", "DawnGraphiteCache",
        "DawnWebGPUCache", "GrShaderCache", "GraphiteDawnCache", "ShaderCache", "component_crx_cache",
        "Service Worker/CacheStorage", "Service Worker/ScriptCache"
    ]

    private static let chromiumRoots = [
        "Google/Chrome", "Google/Chrome Beta", "Google/Chrome Canary", "BraveSoftware/Brave-Browser",
        "Microsoft Edge", "Arc/User Data", "Yandex/YandexBrowser", "Vivaldi", "Chromium", "com.operasoftware.Opera"
    ]

    /// Electron apps and Chromium browsers keep their caches next to user data, not in `~/Library/Caches`.
    private static func embeddedCaches(_ env: ScanEnvironment, _ running: RunningSnapshot) -> ItemGroup? {
        let support = env.library.appending(path: "Application Support")
        var hosts: [(name: String, url: URL)] = children(support)
            .filter { !AppleData.owns(name: $0.lastPathComponent) }
            .map { ($0.lastPathComponent, $0) }
        hosts += chromiumRoots.map { (URL(filePath: $0).lastPathComponent, support.appending(path: $0)) }

        var items: [FoundItem] = []
        var seen: Set<String> = []
        for host in hosts {
            let profiles = children(host.url).filter {
                let name = $0.lastPathComponent
                return name == "Default" || name.hasPrefix("Profile ")
            }
            let isRunning = running.owns(host.name)
            for folder in [host.url] + profiles {
                for cacheName in embeddedCacheNames {
                    let url = folder.appending(path: cacheName)
                    guard FileManager.default.fileExists(atPath: url.path), seen.insert(url.path).inserted else { continue }
                    let size = DirectorySize.allocated(url)
                    guard size >= 5 * megabyte else { continue }
                    let profile = folder == host.url ? "" : " (\(folder.lastPathComponent))"
                    items.append(FoundItem(
                        url: url,
                        title: "\(host.name)\(profile) — \(cacheName)",
                        size: size,
                        date: modified(url),
                        note: isRunning
                            ? String(localized: "Приложение сейчас запущено — закройте его перед очисткой")
                            : String(localized: "Кэш — приложение создаст его заново"),
                        safety: isRunning ? .review : .safe,
                        preselected: !isRunning
                    ))
                }
            }
        }
        return group(
            id: "embedded-caches", title: String(localized: "Кэши браузеров и Electron-приложений"),
            subtitle: String(localized: "Кэш страниц, кода и графики внутри данных приложений. Вкладки, пароли и история не затрагиваются."),
            symbol: "globe", items: items
        )
    }

    private static func logs(_ env: ScanEnvironment) -> ItemGroup? {
        let items = children(env.library.appending(path: "Logs")).compactMap { url -> FoundItem? in
            if AppleData.owns(name: url.lastPathComponent) { return nil }
            let size = DirectorySize.allocated(url)
            guard size >= megabyte else { return nil }
            return FoundItem(
                url: url, size: size, date: modified(url),
                note: String(localized: "Журналы нужны только для диагностики"), safety: .safe, preselected: true
            )
        }
        return group(
            id: "logs", title: String(localized: "Журналы и отчёты о сбоях"),
            subtitle: String(localized: "Диагностические записи приложений."),
            symbol: "doc.text", items: items
        )
    }

    private static func xcode(_ env: ScanEnvironment) -> ItemGroup? {
        let developer = env.library.appending(path: "Developer")
        var items: [FoundItem] = []

        for url in children(developer.appending(path: "Xcode/DerivedData")) {
            // "MyApp-abcdefghijklmnop" → "MyApp".
            var name = url.lastPathComponent
            if let dash = name.lastIndex(of: "-"), name[dash...].count > 20 {
                name = String(name[..<dash])
            }
            items += item(
                url, title: "DerivedData — \(name)", minSize: megabyte,
                note: String(localized: "Промежуточные файлы сборки — Xcode пересоздаст их"), safety: .safe, preselected: true
            )
        }
        for platform in ["iOS", "watchOS", "tvOS", "visionOS", "xrOS"] {
            for url in children(developer.appending(path: "Xcode/\(platform) DeviceSupport")) {
                items += item(
                    url, title: "\(platform) DeviceSupport — \(url.lastPathComponent)", minSize: megabyte,
                    note: String(localized: "Символы для отладки на устройстве — Xcode загрузит их снова при подключении"),
                    safety: .safe, preselected: true
                )
            }
        }
        for url in children(developer.appending(path: "Xcode/Archives")) {
            items += item(
                url, title: String(localized: "Архивы сборок — \(url.lastPathComponent)"), minSize: megabyte,
                note: String(localized: "Нужны для расшифровки отчётов о сбоях уже выпущенных версий"), safety: .caution
            )
        }
        items += item(
            developer.appending(path: "CoreSimulator/Caches"), title: String(localized: "Кэши симуляторов"), minSize: megabyte,
            note: rebuilt("CoreSimulator"), safety: .safe, preselected: true
        )
        return group(
            id: "xcode", title: "Xcode",
            subtitle: String(localized: "Данные сборки и отладки. Проекты и исходный код не затрагиваются."),
            symbol: "hammer", items: items
        )
    }

    private static let developerCachePaths: [(path: String, title: String, safety: Safety, note: String)] = [
        (".npm/_cacache", "npm", .safe, redownloaded("npm")),
        (".npm/_npx", "npx", .safe, redownloaded("npx")),
        (".yarn/cache", "Yarn", .safe, redownloaded("Yarn")),
        (".bun/install/cache", "Bun", .safe, redownloaded("Bun")),
        ("Library/pnpm/store", "pnpm", .safe, redownloaded("pnpm")),
        (".gradle/caches", "Gradle", .safe, redownloaded("Gradle")),
        (".m2/repository", "Maven", .review, String(localized: "Локальный репозиторий Maven — загрузится заново, сборка будет дольше")),
        (".cargo/registry", "Cargo", .safe, redownloaded("Cargo")),
        (".pub-cache", "Dart / Flutter", .review, String(localized: "Пакеты pub — потребуется снова выполнить pub get")),
        (".cocoapods/repos", "CocoaPods", .safe, redownloaded("CocoaPods")),
        ("go/pkg/mod", "Go", .safe, redownloaded("Go")),
        (".nuget/packages", "NuGet", .safe, redownloaded("NuGet")),
        (".android/cache", "Android SDK", .safe, rebuilt("Android SDK")),
        ("Library/Unity/cache", "Unity", .safe, redownloaded("Unity"))
    ]

    private static func developerCaches(_ env: ScanEnvironment) -> ItemGroup? {
        var items: [FoundItem] = []
        for entry in developerCachePaths {
            items += item(
                env.home.appending(path: entry.path), title: entry.title, minSize: 5 * megabyte,
                note: entry.note, safety: entry.safety, preselected: entry.safety == .safe
            )
        }
        for url in children(env.home.appending(path: ".cache")) {
            items += item(
                url, title: "~/.cache — \(url.lastPathComponent)", minSize: 5 * megabyte,
                note: String(localized: "Кэш инструмента командной строки. Скачанные модели и браузеры придётся загрузить заново"),
                safety: .review
            )
        }
        return group(
            id: "dev-caches", title: String(localized: "Кэши инструментов разработки"),
            subtitle: String(localized: "Скачанные пакеты и зависимости. Загружаются заново при следующей установке."),
            symbol: "shippingbox", items: items
        )
    }

    private static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "xip", "ipsw", "iso"]
    private static let partialExtensions: Set<String> = ["crdownload", "part", "opdownload", "download"]
    private static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]

    private static func downloads(_ env: ScanEnvironment) -> ItemGroup? {
        let folder = env.home.appending(path: "Downloads")
        var items: [FoundItem] = []
        var options = WalkOptions()
        options.packagesAsItems = true
        FileWalker.walk(root: folder, env: env, options: options, progress: { _, _ in }, visit: { file in
            let ext = file.url.pathExtension.lowercased()
            if installerExtensions.contains(ext), !file.isPackage {
                items.append(FoundItem(
                    url: file.url, size: file.allocatedSize, date: file.modified,
                    note: String(localized: "Установщик или образ диска — после установки больше не нужен"), safety: .review
                ))
            } else if partialExtensions.contains(ext) {
                guard let modified = file.modified, modified < Date.now.addingTimeInterval(-day) else { return }
                items.append(FoundItem(
                    url: file.url, size: file.allocatedSize, date: file.modified,
                    note: String(localized: "Незавершённая загрузка"), safety: .review
                ))
            } else if archiveExtensions.contains(ext), !file.isPackage {
                var unpacked = file.url.deletingPathExtension()
                if unpacked.pathExtension.lowercased() == "tar" {
                    unpacked = unpacked.deletingPathExtension()
                }
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: unpacked.path, isDirectory: &isDirectory),
                      isDirectory.boolValue
                else { return }
                items.append(FoundItem(
                    url: file.url, size: file.allocatedSize, date: file.modified,
                    note: String(localized: "Архив уже распакован: рядом есть папка «\(unpacked.lastPathComponent)»"), safety: .review
                ))
            }
        })
        return group(
            id: "downloads", title: String(localized: "Установщики и архивы в Загрузках"),
            subtitle: String(localized: "Образы дисков, пакеты установки, распакованные архивы и оборванные загрузки."),
            symbol: "arrow.down.circle", items: items
        )
    }

    private static let screenshotPrefixes = [
        "Снимок экрана", "Запись экрана", "Screenshot", "Screen Shot", "Screen Recording", "스크린샷", "화면 기록",
        "Captura de pantalla", "Grabación de pantalla", "Bildschirmfoto", "Bildschirmaufnahme", "Capture d’écran",
        "Enregistrement de l’écran", "Captura de Tela", "Gravação de Tela", "Istantanea schermo", "Registrazione schermo",
        "截屏", "屏幕录制", "スクリーンショット", "画面収録", "स्क्रीनशॉट", "لقطة الشاشة"
    ]

    private static func screenshots(_ env: ScanEnvironment) -> ItemGroup? {
        var folders = [env.home.appending(path: "Desktop")]
        if env.isRealHome,
           let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let url = URL(filePath: NSString(string: custom).expandingTildeInPath)
            if !folders.contains(where: { $0.path == url.path }) {
                folders.append(url)
            }
        }
        let cutoff = Date.now.addingTimeInterval(-30 * day)
        var items: [FoundItem] = []
        for folder in folders {
            for url in children(folder) {
                let name = url.lastPathComponent.precomposedStringWithCanonicalMapping
                guard screenshotPrefixes.contains(where: { name.hasPrefix($0) }),
                      let date = modified(url), date < cutoff
                else { continue }
                items.append(FoundItem(
                    url: url, size: DirectorySize.allocated(url), date: date,
                    note: String(localized: "Снимок или запись экрана старше 30 дней"), safety: .review
                ))
            }
        }
        return group(
            id: "screenshots", title: String(localized: "Старые снимки и записи экрана"),
            subtitle: String(localized: "Обычно нужны один раз. Проверьте, нет ли среди них важных."),
            symbol: "camera.viewfinder", items: items
        )
    }

    private static func deviceBackups(_ env: ScanEnvironment) -> ItemGroup? {
        let folder = env.library.appending(path: "Application Support/MobileSync/Backup")
        let items = children(folder).compactMap { url -> FoundItem? in
            let size = DirectorySize.allocated(url)
            guard size >= megabyte else { return nil }
            var title = String(localized: "Резервная копия \(String(url.lastPathComponent.prefix(8)))…")
            var date = modified(url)
            if let data = try? Data(contentsOf: url.appending(path: "Info.plist")),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                if let device = plist["Device Name"] as? String {
                    title = String(localized: "Резервная копия: \(device)")
                }
                date = plist["Last Backup Date"] as? Date ?? date
            }
            return FoundItem(
                url: url, title: title, size: size, date: date,
                note: String(localized: "Удаляйте, только если копия устройства точно не понадобится"), safety: .caution
            )
        }
        return group(
            id: "backups", title: String(localized: "Резервные копии iPhone и iPad"),
            subtitle: String(localized: "Локальные копии устройств, сделанные через Finder."),
            symbol: "iphone", items: items
        )
    }

    private static func firmware(_ env: ScanEnvironment) -> ItemGroup? {
        var items: [FoundItem] = []
        for device in ["iPhone", "iPad", "iPod"] {
            for url in children(env.library.appending(path: "iTunes/\(device) Software Updates")) {
                items += item(
                    url, title: url.lastPathComponent, minSize: megabyte,
                    note: String(localized: "Файл прошивки — после обновления устройства не нужен"), safety: .safe, preselected: true
                )
            }
        }
        return group(
            id: "firmware", title: String(localized: "Прошивки устройств"),
            subtitle: String(localized: "Скачанные обновления iOS и iPadOS."),
            symbol: "arrow.triangle.2.circlepath", items: items
        )
    }

    private static func mailDownloads(_ env: ScanEnvironment) -> ItemGroup? {
        let folder = env.library.appending(path: "Containers/com.apple.mail/Data/Library/Mail Downloads")
        let items = children(folder).flatMap { url in
            item(
                url, title: url.lastPathComponent, minSize: megabyte,
                note: String(localized: "Копия вложения, открытого из Почты. Само письмо остаётся в ящике"), safety: .review
            )
        }
        return group(
            id: "mail", title: String(localized: "Вложения Почты"),
            subtitle: String(localized: "Вложения, которые открывались из писем."),
            symbol: "envelope", items: items
        )
    }

    // MARK: - Helpers

    private static func children(_ directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Zero or one item, depending on whether the path exists and is big enough to be worth listing.
    private static func item(
        _ url: URL, title: String, minSize: Int64, note: String, safety: Safety, preselected: Bool = false
    ) -> [FoundItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let size = DirectorySize.allocated(url)
        guard size >= minSize else { return [] }
        return [FoundItem(
            url: url, title: title, size: size, date: modified(url),
            note: note, safety: safety, preselected: preselected
        )]
    }

    private static func group(id: String, title: String, subtitle: String, symbol: String, items: [FoundItem]) -> ItemGroup? {
        guard !items.isEmpty else { return nil }
        return ItemGroup(
            id: id, title: title, subtitle: subtitle, symbol: symbol,
            items: items.sorted { $0.size > $1.size }
        )
    }
}
