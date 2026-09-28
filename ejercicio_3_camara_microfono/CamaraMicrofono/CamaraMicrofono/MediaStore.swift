import Foundation
import UIKit
import CoreData

/// Se encarga de guardar los archivos (fotos/audio) en el sandbox de la
/// app (Documents/Capturas) y de crear/eliminar su registro
/// correspondiente en Core Data.
enum MediaStore {
    static var capturesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Capturas", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    static func savePhoto(_ image: UIImage, filterUsed: String?) -> MediaItem? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let fileName = "foto_\(UUID().uuidString).jpg"
        let url = capturesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
        } catch {
            print("Error guardando foto: \(error)")
            return nil
        }
        return createRecord(type: "photo", fileName: fileName, duration: 0, filterUsed: filterUsed)
    }

    @discardableResult
    static func registerAudio(fileName: String, duration: TimeInterval) -> MediaItem? {
        createRecord(type: "audio", fileName: fileName, duration: duration, filterUsed: nil)
    }

    private static func createRecord(type: String, fileName: String, duration: Double, filterUsed: String?) -> MediaItem? {
        let context = PersistenceController.shared.container.viewContext
        let item = MediaItem(context: context)
        item.id = UUID()
        item.type = type
        item.fileName = fileName
        item.createdAt = Date()
        item.duration = duration
        item.filterUsed = filterUsed
        PersistenceController.shared.save()
        return item
    }

    static func delete(_ item: MediaItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        let context = PersistenceController.shared.container.viewContext
        context.delete(item)
        PersistenceController.shared.save()
    }
}
