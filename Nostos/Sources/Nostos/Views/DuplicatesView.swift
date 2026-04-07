import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Duplicates")
                    .font(.largeTitle).bold()
                Spacer()
                Text("\(state.duplicateGroups.count) groups")
                    .foregroundColor(.secondary)
            }
            .padding(24)

            Divider()

            if state.duplicateGroups.isEmpty {
                ContentUnavailableView(
                    "No Duplicates Found",
                    systemImage: "checkmark.seal",
                    description: Text("Run a scan to detect duplicate photos.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(state.duplicateGroups) { group in
                            DuplicateGroupRow(group: group)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DuplicateGroupRow: View {
    @EnvironmentObject var state: AppState
    let group: DuplicateGroupWithPhotos

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(group.group.reason == .hashMatch ? "Exact Match" : "Near Duplicate",
                          systemImage: group.group.reason == .hashMatch ? "equal.circle" : "arrow.triangle.2.circlepath")
                        .font(.headline)
                    Spacer()
                    Text("\(group.photos.count) photos")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(group.photos) { photo in
                            DuplicatePhotoCard(
                                photo: photo,
                                isKept: photo.isKept,
                                onKeep: {
                                    if let groupId = group.group.id, let photoId = photo.id {
                                        state.setKeptPhoto(groupId: groupId, photoId: photoId)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}

struct DuplicatePhotoCard: View {
    let photo: Photo
    let isKept: Bool
    let onKeep: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(width: 140, height: 140)
                .clipped()
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isKept ? Color.green : Color.clear, lineWidth: 3)
                )

                if isKept {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .background(Color.white.clipShape(Circle()))
                        .padding(4)
                }
            }

            Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 140)

            if let date = photo.takenAt {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                .font(.caption2)
                .foregroundColor(.secondary)

            Button(isKept ? "Kept" : "Keep This") {
                onKeep()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isKept)
            .frame(width: 140)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        Task.detached(priority: .userInitiated) {
            let loaded: NSImage? = {
                if let path = photo.thumbnailPath {
                    return ThumbnailService.loadImage(path: path)
                }
                if let photoId = photo.id {
                    let path = ThumbnailService.thumbnail(
                        for: photoId,
                        sourceURL: URL(fileURLWithPath: photo.path)
                    )
                    return path.flatMap { ThumbnailService.loadImage(path: $0) }
                }
                return nil
            }()
            await MainActor.run { image = loaded }
        }
    }
}
