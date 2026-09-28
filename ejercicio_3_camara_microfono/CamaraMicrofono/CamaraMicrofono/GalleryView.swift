import SwiftUI
import CoreData

/// Pestaña de galería: muestra en una cuadricula todas las fotos y
/// audios capturados (leidos de Core Data), ordenados del mas reciente
/// al mas antiguo.
struct GalleryView: View {
    @EnvironmentObject var settings: AppSettings
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MediaItem.createdAt, ascending: false)]
    ) private var items: FetchedResults<MediaItem>

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableFallback(
                        title: "Sin elementos",
                        message: "Las fotos y audios que captures van a aparecer aqui."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(items) { item in
                                NavigationLink {
                                    destinationView(for: item)
                                } label: {
                                    thumbnail(for: item)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .navigationTitle("Galería")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Tema", selection: $settings.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                    } label: {
                        Image(systemName: "paintbrush.fill")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for item: MediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            if item.isPhoto, let uiImage = UIImage(contentsOfFile: item.fileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.theme.accentColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundStyle(settings.theme.accentColor)
                    }
            }
            Image(systemName: item.isPhoto ? "photo" : "mic")
                .font(.caption2)
                .padding(4)
                .background(.black.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(Circle())
                .padding(4)
        }
    }

    @ViewBuilder
    private func destinationView(for item: MediaItem) -> some View {
        if item.isPhoto {
            PhotoDetailView(item: item)
        } else {
            AudioDetailView(item: item)
        }
    }
}

/// Placeholder reutilizable para listas vacias.
struct ContentUnavailableFallback: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
