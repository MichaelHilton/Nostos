import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: Text?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .foregroundColor(.secondary)
                .padding(8)

            Text(title)
                .font(.title2)
                .bold()

            if let description = description {
                description
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
