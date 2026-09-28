import Foundation
import Combine

/// Controla el listado, busqueda, orden y operaciones de archivos
/// (crear, copiar, mover, renombrar, eliminar) para UNA carpeta.
/// Cada pantalla de carpeta crea su propia instancia con la URL
/// correspondiente (esto es lo que permite la navegacion jerarquica).
final class FileBrowserViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var searchText: String = ""
    @Published var errorMessage: String?

    let currentURL: URL
    private let fileManager = FileManager.default

    init(url: URL) {
        self.currentURL = url
        loadItems()
    }

    func loadItems() {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: currentURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            var loaded: [FileItem] = []
            for url in contents {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                loaded.append(FileItem(
                    id: url.path,
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: values.isDirectory ?? false,
                    size: Int64(values.fileSize ?? 0),
                    modificationDate: values.contentModificationDate ?? Date()
                ))
            }
            self.items = loaded
            self.errorMessage = nil
        } catch {
            errorMessage = "No se pudo leer la carpeta: \(error.localizedDescription)"
            self.items = []
        }
    }

    func filteredAndSorted(by sortOption: SortOption) -> [FileItem] {
        var result = items
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortOption {
        case .name:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            result.sort { $0.modificationDate > $1.modificationDate }
        case .size:
            result.sort { $0.size > $1.size }
        }
        // Las carpetas siempre primero, sin romper el orden elegido dentro de cada grupo.
        let folders = result.filter { $0.isDirectory }
        let files = result.filter { !$0.isDirectory }
        return folders + files
    }

    func createFolder(named name: String) {
        guard !name.isEmpty else { return }
        let newURL = currentURL.appendingPathComponent(name, isDirectory: true)
        do {
            try fileManager.createDirectory(at: newURL, withIntermediateDirectories: false)
            loadItems()
        } catch {
            errorMessage = "No se pudo crear la carpeta: \(error.localizedDescription)"
        }
    }

    func delete(_ item: FileItem) {
        do {
            try fileManager.removeItem(at: item.url)
            loadItems()
        } catch {
            errorMessage = "No se pudo eliminar: \(error.localizedDescription)"
        }
    }

    func rename(_ item: FileItem, to newName: String) {
        guard !newName.isEmpty, newName != item.name else { return }
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fileManager.moveItem(at: item.url, to: newURL)
            loadItems()
        } catch {
            errorMessage = "No se pudo renombrar: \(error.localizedDescription)"
        }
    }

    func duplicate(_ item: FileItem) {
        var destURL = item.url
        var counter = 1
        let base = item.url.deletingPathExtension().lastPathComponent
        let ext = item.url.pathExtension
        while fileManager.fileExists(atPath: destURL.path) {
            let newName = ext.isEmpty ? "\(base) copia \(counter)" : "\(base) copia \(counter).\(ext)"
            destURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        do {
            try fileManager.copyItem(at: item.url, to: destURL)
            loadItems()
        } catch {
            errorMessage = "No se pudo copiar: \(error.localizedDescription)"
        }
    }

    func importFile(from sourceURL: URL) {
        let destURL = currentURL.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
            loadItems()
        } catch {
            errorMessage = "No se pudo importar el archivo: \(error.localizedDescription)"
        }
    }
}
