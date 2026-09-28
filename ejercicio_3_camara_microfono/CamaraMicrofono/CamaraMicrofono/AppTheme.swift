import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case guinda
    case azul

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .guinda: return "Guinda (IPN)"
        case .azul: return "Azul (ESCOM)"
        }
    }

    // Colores representativos. Se usan como acento; el resto de la interfaz
    // (fondos, texto) usa colores semanticos del sistema para adaptarse
    // automaticamente a modo claro/oscuro.
    var accentColor: Color {
        switch self {
        case .guinda:
            return Color(red: 0.60, green: 0.05, blue: 0.20)
        case .azul:
            return Color(red: 0.03, green: 0.20, blue: 0.55)
        }
    }
}
