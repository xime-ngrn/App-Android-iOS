import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            RootFoldersView()
                .tabItem { Label("Archivos", systemImage: "folder") }

            FavoritesView()
                .tabItem { Label("Favoritos", systemImage: "star") }

            RecentsView()
                .tabItem { Label("Recientes", systemImage: "clock") }
        }
        .tint(settings.theme.accentColor)
        // No forzamos preferredColorScheme: la app respeta el modo
        // claro/oscuro que el usuario tenga elegido en el sistema.
    }
}
