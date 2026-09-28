import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("Cámara", systemImage: "camera") }
            AudioRecorderView()
                .tabItem { Label("Audio", systemImage: "mic") }
            GalleryView()
                .tabItem { Label("Galería", systemImage: "photo.on.rectangle") }
        }
        .tint(settings.theme.accentColor)
    }
}
