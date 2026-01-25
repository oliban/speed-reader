import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            URLInputView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
