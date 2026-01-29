import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home

    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground
                .ignoresSafeArea()

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .home:
                    URLInputView()
                case .library:
                    LibraryView()
                case .settings:
                    SettingsView()
                }
            }
            .padding(.bottom, 80) // Space for floating tab bar

            // Floating tab bar
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

#Preview {
    MainTabView()
}
