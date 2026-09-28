import SwiftUI
import CoreData

@main
struct CamaraMicrofonoApp: App {
    @StateObject private var settings = AppSettings()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
