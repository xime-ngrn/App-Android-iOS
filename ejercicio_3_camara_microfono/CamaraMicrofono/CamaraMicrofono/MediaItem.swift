import CoreData
import Foundation

/// Registro de Core Data para una foto o un audio capturado. El archivo
/// real (jpg / m4a) vive en Documents/Capturas; aqui solo guardamos los
/// metadatos para poder listarlos, ordenarlos y borrarlos facilmente.
@objc(MediaItem)
final class MediaItem: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var type: String // "photo" o "audio"
    @NSManaged var fileName: String
    @NSManaged var createdAt: Date
    @NSManaged var duration: Double // solo aplica a audio
    @NSManaged var filterUsed: String?

    var isPhoto: Bool { type == "photo" }
    var isAudio: Bool { type == "audio" }

    /// URL en el sandbox donde vive el archivo real.
    var fileURL: URL {
        MediaStore.capturesDirectory.appendingPathComponent(fileName)
    }
}

extension MediaItem {
    static func fetchRequest() -> NSFetchRequest<MediaItem> {
        NSFetchRequest<MediaItem>(entityName: "MediaItem")
    }
}
