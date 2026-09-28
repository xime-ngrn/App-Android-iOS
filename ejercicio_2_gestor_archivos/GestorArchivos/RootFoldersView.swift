import SwiftUI

/// Pantalla de inicio: enlaza a los tres directorios accesibles dentro
/// del sandbox de la app (Documents, Inbox y tmp), tal como pide el
/// ejercicio. "Documents" es donde el usuario guarda/importa sus
/// archivos; "Inbox" recibe archivos abiertos desde otras apps; "tmp"
/// es almacenamiento temporal.
struct RootFoldersView: View {
    @EnvironmentObject var settings: AppSettings

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var inboxURL: URL {
        ensureExists(documentsURL.appendingPathComponent("Inbox", isDirectory: true))
    }
    private var tmpURL: URL {
        FileManager.default.temporaryDirectory
    }

    private var rootItems: [FileItem] {
        [
            FileItem(id: "root-documents", url: documentsURL, name: "Documents", isDirectory: true, size: 0, modificationDate: Date()),
            FileItem(id: "root-inbox", url: inboxURL, name: "Inbox", isDirectory: true, size: 0, modificationDate: Date()),
            FileItem(id: "root-tmp", url: tmpURL, name: "tmp", isDirectory: true, size: 0, modificationDate: Date())
        ]
    }

    private func icon(for name: String) -> String {
        switch name {
        case "Documents": return "folder.fill"
        case "Inbox": return "tray.and.arrow.down.fill"
        default: return "clock.arrow.circlepath"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Directorios del sandbox") {
                    ForEach(rootItems) { item in
                        NavigationLink(value: item) {
                            Label(item.name, systemImage: icon(for: item.name))
                        }
                    }
                }
            }
            .navigationDestination(for: FileItem.self) { item in
                FileBrowserView(url: item.url, title: item.name, pathComponents: [item.name])
            }
            .navigationTitle("Gestor de Archivos")
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

    private func ensureExists(_ url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
