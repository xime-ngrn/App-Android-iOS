import CoreData

/// Controlador de Core Data. El modelo se construye programaticamente
/// (sin archivo .xcdatamodeld) para simplificar la integracion: una sola
/// entidad "MediaItem" que guarda los metadatos de cada foto o audio
/// capturado (nombre de archivo, tipo, fecha, filtro usado, duracion).
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        let model = PersistenceController.makeModel()
        container = NSPersistentContainer(name: "CamaraMicrofono", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error {
                print("Error cargando Core Data: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "MediaItem"
        entity.managedObjectClassName = "MediaItem"

        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            return attr
        }

        let idAttr = attribute("id", .UUIDAttributeType)
        let typeAttr = attribute("type", .stringAttributeType)
        let fileNameAttr = attribute("fileName", .stringAttributeType)
        let createdAtAttr = attribute("createdAt", .dateAttributeType)
        let durationAttr = attribute("duration", .doubleAttributeType)
        let filterAttr = attribute("filterUsed", .stringAttributeType, optional: true)

        entity.properties = [idAttr, typeAttr, fileNameAttr, createdAtAttr, durationAttr, filterAttr]
        model.entities = [entity]
        return model
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error guardando Core Data: \(error)")
        }
    }
}
