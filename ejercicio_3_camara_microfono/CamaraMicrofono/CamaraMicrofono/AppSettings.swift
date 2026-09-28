import Foundation
import Combine

/// Estado persistente de la app: por ahora solo el tema elegido
/// (Guinda/Azul), guardado en UserDefaults para recordarlo entre
/// sesiones.
final class AppSettings: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "camara_theme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "camara_theme") ?? AppTheme.guinda.rawValue
        self.theme = AppTheme(rawValue: saved) ?? .guinda
    }
}
