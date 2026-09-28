import SwiftUI

/// Convierte una ruta guardada (String) de vuelta a un FileItem,
/// leyendo sus atributos actuales del sistema de archivos.
private func fileItem(fromPath path: String) -> FileItem? {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
    return FileItem(
        id: path,
        url: url,
        name: url.lastPathComponent,
        isDirectory: values?.isDirectory ?? false,
        size: Int64(values?.fileSize ?? 0),
        modificationDate: values?.contentModificationDate ?? Date()
    )
}

/// Pestaña de favoritos: archivos y carpetas marcados con la estrella,
/// persistidos en UserDefaults a traves de AppSettings.
struct FavoritesView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var previewItem: FileItem?

    var body: some View {
        NavigationStack {
            List {
                let items = settings.favorites.compactMap(fileItem(fromPath:))
                if items.isEmpty {
                    ContentUnavailableFallback(
                        title: "Sin favoritos",
                        message: "Desliza un archivo hacia la izquierda o usa el menu contextual para agregarlo aqui."
                    )
                } else {
                    ForEach(items) { item in
                        Button {
                            if item.isDirectory {
                                // Para carpetas favoritas, no se abre un preview.
                            } else {
                                previewItem = item
                            }
                        } label: {
                            if item.isDirectory {
                                NavigationLink {
                                    FileBrowserView(url: item.url, title: item.name)
                                } label: {
                                    FileRowView(item: item, isFavorite: true)
                                }
                            } else {
                                FileRowView(item: item, isFavorite: true)
                            }
                        }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            Button(role: .destructive) {
                                settings.toggleFavorite(item.id)
                            } label: {
                                Label("Quitar", systemImage: "star.slash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoritos")
            .sheet(item: $previewItem) { item in
                NavigationStack {
                    Group {
                        if item.isImage {
                            ImageViewerView(url: item.url)
                        } else if item.isText {
                            TextFileViewerView(url: item.url)
                        } else {
                            QuickLookPreview(url: item.url)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { previewItem = nil }
                        }
                    }
                }
            }
        }
    }
}

/// Pestaña de recientes: ultimos archivos abiertos, en orden de uso.
struct RecentsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var previewItem: FileItem?

    var body: some View {
        NavigationStack {
            List {
                let items = settings.recents.compactMap(fileItem(fromPath:))
                if items.isEmpty {
                    ContentUnavailableFallback(
                        title: "Sin archivos recientes",
                        message: "Los archivos que abras van a aparecer aqui."
                    )
                } else {
                    ForEach(items) { item in
                        Button {
                            previewItem = item
                        } label: {
                            FileRowView(item: item, isFavorite: settings.favorites.contains(item.id))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Recientes")
            .sheet(item: $previewItem) { item in
                NavigationStack {
                    Group {
                        if item.isImage {
                            ImageViewerView(url: item.url)
                        } else if item.isText {
                            TextFileViewerView(url: item.url)
                        } else {
                            QuickLookPreview(url: item.url)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { previewItem = nil }
                        }
                    }
                }
            }
        }
    }
}

/// Pequeño placeholder reutilizable (equivalente simplificado de
/// ContentUnavailableView, compatible con versiones previas de iOS).
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
}
