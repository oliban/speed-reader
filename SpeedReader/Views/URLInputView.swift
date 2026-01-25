import SwiftUI

struct URLInputView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Enter URL to read")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    URLInputView()
}
