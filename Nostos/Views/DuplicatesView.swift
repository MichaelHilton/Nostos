import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var state: AppState
    @State private var expandedGroupId: Int64?

    var subtitle: String {
        let totalPhotos = state.duplicateGroups.reduce(0) { $0 + $1.photos.count }
        let resolved = state.duplicateGroups.filter { group in
            group.photos.contains { $0.isKept }
        }.count
        return "\(state.duplicateGroups.count) groups · \(totalPhotos) photos · \(resolved) of \(state.duplicateGroups.count) resolved"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeaderView(
                title: "Duplicates",
                subtitle: subtitle
            )

            if state.duplicateGroups.isEmpty {
                EmptyStateView(
                    title: "No Duplicates Found",
                    systemImage: "checkmark.seal",
                    description: Text("Run a scan to detect duplicate photos.")
                )
            } else {
                ScrollView {
                    VStack(spacing: NostosSpacing.xxxl) {
                        StarDotBackground()

                        let columns = [GridItem(.adaptive(minimum: 280), spacing: NostosSpacing.lg)]
                        LazyVGrid(columns: columns, spacing: NostosSpacing.lg) {
                            ForEach(state.duplicateGroups) { group in
                                dupGroupCardView(group)
                            }
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)

                        Divider()
                            .padding(.horizontal, NostosSpacing.pagePadding)

                        footerActions
                            .padding(.horizontal, NostosSpacing.pagePadding)
                            .padding(.vertical, NostosSpacing.lg)
                    }
                    .padding(.vertical, NostosSpacing.xxxl)
                }
                .background(Color.nostosBg)
                .overlay(alignment: .topLeading) {
                    StarDotBackground()
                }
            }
        }
    }

    @ViewBuilder
    private var footerActions: some View {
        HStack(spacing: NostosSpacing.md) {
            Button(action: keepFirstInAllGroups) {
                Text("Keep First in All Groups")
            }
            .buttonStyle(.bordered)

            Button(action: clearSelections) {
                Text("Clear Selections")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.nostosRed)

            Spacer()
        }
    }

    @ViewBuilder
    private func dupGroupCardView(_ group: DuplicateGroupWithPhotos) -> some View {
        let isExpanded = expandedGroupId == group.group.id
        DupGroupCard(
            group: group,
            isExpanded: isExpanded,
            onToggleExpand: {
                expandedGroupId = expandedGroupId == group.group.id ? nil : group.group.id
            }
        )
    }

    private func keepFirstInAllGroups() {
        for group in state.duplicateGroups {
            if let first = group.photos.first,
               let groupId = group.group.id,
               let photoId = first.id {
                state.setKeptPhoto(groupId: groupId, photoId: photoId)
            }
        }
    }

    private func clearSelections() {
        for group in state.duplicateGroups {
            for photo in group.photos {
                if photo.isKept,
                   let groupId = group.group.id,
                   let photoId = photo.id {
                    state.setKeptPhoto(groupId: groupId, photoId: photoId)
                }
            }
        }
    }
}

struct DupGroupCard: View {
    @EnvironmentObject var state: AppState
    let group: DuplicateGroupWithPhotos
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var isResolved: Bool {
        group.photos.contains { $0.isKept }
    }

    var borderColor: Color {
        isResolved ? Color.nostosGreen : Color.nostosBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: NostosSpacing.md) {
                HStack(spacing: 6) {
                    DiamondAccent(size: 5)
                    Text(group.group.reason == .hashMatch ? "Exact" : "Near")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, NostosSpacing.sm)
                        .padding(.vertical, 2)
                        .background(group.group.reason == .hashMatch ? Color.nostosOrange : Color.nostosAccent)
                        .cornerRadius(NostosRadii.sm)
                }

                Text("\(group.photos.count) photos")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosFg2)

                if isResolved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.nostosGreen)
                        Text("Resolved")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.nostosGreen)
                    }
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.nostosFg2)
                }
                .buttonStyle(.plain)
            }
            .padding(NostosSpacing.lg)

            if isExpanded {
                Divider()
                    .padding(0)

                // Thumbnails grid
                VStack(alignment: .leading, spacing: NostosSpacing.md) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: NostosSpacing.md)], spacing: NostosSpacing.md) {
                        ForEach(group.photos) { photo in
                            DupPhotoThumb(
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
                .padding(NostosSpacing.lg)
            }
        }
        .background(Color.nostosSurface)
        .border(borderColor, width: 1.5)
        .cornerRadius(NostosRadii.xl)
    }
}

struct DupPhotoThumb: View {
    let photo: Photo
    let isKept: Bool
    let onKeep: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.nostosProgressBg)
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(width: 86, height: 86)
                .clipped()
                .cornerRadius(NostosRadii.md)
                .overlay(
                    RoundedRectangle(cornerRadius: NostosRadii.md)
                        .stroke(isKept ? Color.nostosGreen : Color.clear, lineWidth: 2.5)
                )
                .onTapGesture {
                    onKeep()
                }
                .accessibilityIdentifier("duplicatePhotoTile")

                if isKept {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.nostosGreen)
                        .background(Color.nostosSurface.clipShape(Circle()))
                        .padding(4)
                }
            }

            Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg1)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 86)
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
