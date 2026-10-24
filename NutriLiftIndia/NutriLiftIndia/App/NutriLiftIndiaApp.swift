import SwiftUI
import SwiftData

@main
struct NutriLiftIndiaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = AppSchema.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
