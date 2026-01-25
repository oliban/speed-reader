import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Configure your reading preferences")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
