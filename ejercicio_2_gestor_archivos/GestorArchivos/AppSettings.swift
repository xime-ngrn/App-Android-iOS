import Foundation
import SwiftUI
import Combine

/// Estado global persistente: tema seleccionado, favoritos, historial
/// reciente y ultima carpeta visitada. Se guarda todo en UserDefaults
/// para que sobreviva a que se cierre la app (almacenamiento local).
final class AppSettings: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme") }
    }
    @Published var favorites: Set<String> {
        didSet { UserDefaults.standard.set(Array(favorites), forKey: "favoritePaths") }
    }
    @Published var recents: [String] {
        didSet { UserDefaults.standard.set(recents, forKey: "recentPaths") }
    }
    @Published var lastVisitedPath: String {
        didSet { UserDefaults.standard.set(lastVisitedPath, forKey: "lastVisitedPath") }
    }
    @Published var sortOption: SortOption {
        didSet { UserDefaults.standard.set(sortOption.rawValue, forKey: "sortOption") }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.guinda.rawValue
        self.theme = AppTheme(rawValue: savedTheme) ?? .guinda
        self.favorites = Set(UserDefaults.standard.stringArray(forKey: "favoritePaths") ?? [])
        self.recents = UserDefaults.standard.stringArray(forKey: "recentPaths") ?? []
        self.lastVisitedPath = UserDefaults.standard.string(forKey: "lastVisitedPath") ?? ""
        let savedSort = UserDefaults.standard.string(forKey: "sortOption") ?? SortOption.name.rawValue
        self.sortOption = SortOption(rawValue: savedSort) ?? .name
    }

    func toggleFavorite(_ path: String) {
        if favorites.contains(path) {
            favorites.remove(path)
        } else {
            favorites.insert(path)
        }
    }

    func addRecent(_ path: String) {
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        if recents.count > 20 { recents = Array(recents.prefix(20)) }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case name = "Nombre"
    case date = "Fecha"
    case size = "Tamaño"
    var id: String { rawValue }
}
