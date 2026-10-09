import Foundation

enum SectionKind: String, CaseIterable, Identifiable, Sendable {
    case overview
    case junk
    case duplicates
    case large
    case old
    case leftovers
    case apps

    static let scannable: [SectionKind] = [.junk, .duplicates, .large, .old, .leftovers]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: String(localized: "Обзор")
        case .junk: String(localized: "Мусор")
        case .duplicates: String(localized: "Дубликаты")
        case .large: String(localized: "Большие файлы")
        case .old: String(localized: "Давно не использовались")
        case .leftovers: String(localized: "Остатки приложений")
        case .apps: String(localized: "Приложения")
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .junk: "trash"
        case .duplicates: "doc.on.doc"
        case .large: "externaldrive"
        case .old: "clock.arrow.circlepath"
        case .leftovers: "puzzlepiece.extension"
        case .apps: "square.grid.2x2"
        }
    }

    var blurb: String {
        switch self {
        case .overview:
            String(localized: "Состояние диска и быстрый запуск всех проверок.")
        case .junk:
            String(localized: "Кэши, журналы, старые установщики и прочее, что можно удалить без потери данных. Безопасное отмечено заранее.")
        case .duplicates:
            String(localized: "Файлы с полностью одинаковым содержимым. Сравнение идёт по содержимому, а не по имени.")
        case .large:
            String(localized: "Самые тяжёлые файлы и пакеты. Решайте сами, что из этого ещё нужно.")
        case .old:
            String(localized: "Файлы, которые давно не открывались и не изменялись.")
        case .leftovers:
            String(localized: "Настройки, кэши и данные приложений, которых на этом Mac уже нет.")
        case .apps:
            String(localized: "Установленные приложения с размером и датой последнего запуска. Удаление забирает и связанные файлы.")
        }
    }

    /// Junk categories are long, so they start collapsed.
    var startsCollapsed: Bool { self == .junk }

    /// Large and old files are shown as one flat list.
    var isGrouped: Bool { self != .large && self != .old }
}
