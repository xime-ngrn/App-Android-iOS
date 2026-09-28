import SwiftUI
import UniformTypeIdentifiers

/// Pantalla principal: lista el contenido de UNA carpeta y permite
/// navegar a subcarpetas (NavigationStack), buscar, ordenar, crear
/// carpetas, importar, renombrar, eliminar, marcar favoritos y
/// compartir. Cada nivel de la jerarquia crea otra instancia de esta
/// misma vista con la URL de la subcarpeta, y arrastra la ruta completa
/// (pathComponents) para mostrarla siempre visible como breadcrumb.
struct FileBrowserView: View {
    @StateObject private var viewModel: FileBrowserViewModel
    @EnvironmentObject var settings: AppSettings

    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showDocumentPicker = false
    @State private var selectedFileForPreview: FileItem?
    @State private var itemToShare: FileItem?
    @State private var itemToRename: FileItem?
    @State private var renameText = ""
    @State private var itemToDelete: FileItem?
    @State private var showDeleteConfirm = false

    private let rootTitle: String
    private let pathComponents: [String]

    init(url: URL, title: String = "", pathComponents: [String] = []) {
        _viewModel = StateObject(wrappedValue: FileBrowserViewModel(url: url))
        self.rootTitle = title
        self.pathComponents = pathComponents
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            List {
                ForEach(viewModel.filteredAndSorted(by: settings.sortOption)) { item in
                    rowView(for: item)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: FileItem.self) { item in
                FileBrowserView(url: item.url, title: item.name, pathComponents: pathComponents + [item.name])
            }
            .searchable(text: $viewModel.searchText, prompt: "Buscar en esta carpeta")
            .refreshable { viewModel.loadItems() }
        }
        .navigationTitle(rootTitle.isEmpty ? (viewModel.currentURL.lastPathComponent.isEmpty ? "Documentos" : viewModel.currentURL.lastPathComponent) : rootTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Nueva carpeta", isPresented: $showNewFolderAlert) {
            TextField("Nombre de la carpeta", text: $newFolderName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { viewModel.createFolder(named: newFolderName) }
        }
        .alert("Renombrar", isPresented: Binding(
            get: { itemToRename != nil },
            set: { if !$0 { itemToRename = nil } }
        )) {
            TextField("Nuevo nombre", text: $renameText)
            Button("Cancelar", role: .cancel) { itemToRename = nil }
            Button("Guardar") {
                if let item = itemToRename { viewModel.rename(item, to: renameText) }
                itemToRename = nil
            }
        }
        .confirmationDialog("¿Eliminar este elemento? Esta accion no se puede deshacer.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let item = itemToDelete { viewModel.delete(item) }
                itemToDelete = nil
            }
            Button("Cancelar", role: .cancel) { itemToDelete = nil }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                viewModel.importFile(from: url)
            }
        }
        .sheet(item: $itemToShare) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: $selectedFileForPreview) { item in
            NavigationStack {
                destinationView(for: item)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { selectedFileForPreview = nil }
                        }
                    }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            settings.lastVisitedPath = viewModel.currentURL.path
        }
    }

    /// Renglon fijo (no se mueve al hacer scroll) que muestra la ruta
    /// completa desde la raiz hasta la carpeta actual, siempre visible.
    @ViewBuilder
    private var breadcrumbBar: some View {
        if !pathComponents.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.caption2)
                Text(pathComponents.joined(separator: " › "))
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.thinMaterial)
        }
    }

    @ViewBuilder
    private func rowView(for item: FileItem) -> some View {
        Group {
            if item.isDirectory {
                NavigationLink(value: item) {
                    FileRowView(item: item, isFavorite: settings.favorites.contains(item.id))
                }
            } else {
                Button {
                    openFile(item)
                } label: {
                    FileRowView(item: item, isFavorite: settings.favorites.contains(item.id))
                }
                .foregroundStyle(.primary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirm = true
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                settings.toggleFavorite(item.id)
            } label: {
                Label("Favorito", systemImage: settings.favorites.contains(item.id) ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
        .contextMenu {
            Button {
                itemToRename = item
                renameText = item.name
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            if !item.isDirectory {
                Button {
                    viewModel.duplicate(item)
                } label: {
                    Label("Duplicar", systemImage: "doc.on.doc")
                }
                Button {
                    itemToShare = item
                } label: {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                settings.toggleFavorite(item.id)
            } label: {
                Label(settings.favorites.contains(item.id) ? "Quitar de favoritos" : "Agregar a favoritos", systemImage: "star")
            }
            Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirm = true
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Ordenar por", selection: $settings.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Importar archivo", systemImage: "square.and.arrow.down")
                }
                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label("Nueva carpeta", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func openFile(_ item: FileItem) {
        settings.addRecent(item.id)
        selectedFileForPreview = item
    }

    @ViewBuilder
    private func destinationView(for item: FileItem) -> some View {
        if item.isImage {
            ImageViewerView(url: item.url)
        } else if item.isText {
            TextFileViewerView(url: item.url)
        } else {
            QuickLookPreview(url: item.url)
        }
    }
}
