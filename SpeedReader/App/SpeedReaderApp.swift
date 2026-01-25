import SwiftUI
import SwiftData

@main
struct SpeedReaderApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Article.self,
            ReadingProgress.self,
            AppSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Root view that applies the user's preferred color scheme
struct AppContentView: View {
    @Query private var settingsArray: [AppSettings]

    private var settings: AppSettings? {
        settingsArray.first
    }

    private var colorScheme: ColorScheme? {
        guard let mode = settings?.appearanceMode else { return nil }
        switch mode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    var body: some View {
        MainTabView()
            .preferredColorScheme(colorScheme)
    }
}
