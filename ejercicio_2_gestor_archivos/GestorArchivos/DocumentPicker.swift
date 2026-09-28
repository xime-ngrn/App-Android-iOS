import SwiftUI
import UniformTypeIdentifiers

/// Envuelve UIDocumentPickerViewController para importar archivos desde
/// la app Archivos de iOS o desde iCloud Drive. Copia el archivo elegido
/// dentro del sandbox de nuestra app usando un "security-scoped bookmark"
/// mientras se tiene acceso, tal como exige iOS para archivos externos.
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // El acceso a rutas fuera del sandbox requiere un bookmark
                // con alcance de seguridad mientras se usa el recurso.
                guard url.startAccessingSecurityScopedResource() else { continue }
                onPick(url)
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
