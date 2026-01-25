import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Your saved articles")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
}
