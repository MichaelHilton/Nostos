import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var state: AppState

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
                        let columns = [GridItem(.adaptive(minimum: 300), spacing: NostosSpacing.lg)]
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
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private var footerActions: some View {
        HStack(spacing: NostosSpacing.sm) {
            footerButton("Keep First in All Groups", icon: "1.circle", color: .nostosGreen) {
                keepFirstInAllGroups()
            }
            .accessibilityIdentifier("duplicatesKeepFirstButton")

            footerButton("Keep All in All Groups", icon: "checkmark.circle", color: .nostosAccent) {
                keepAllInAllGroups()
            }
            .accessibilityIdentifier("duplicatesKeepAllButton")

            footerButton("Clear Selections", icon: "xmark.circle", color: .nostosRed) {
                clearSelections()
            }
            .accessibilityIdentifier("duplicatesClearSelectionsButton")

            Spacer()
        }
    }

    @ViewBuilder
    private func footerButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.nostosLabel)
            }
            .foregroundColor(color)
            .padding(.horizontal, NostosSpacing.md)
            .padding(.vertical, NostosSpacing.sm)
            .background(color.opacity(0.07))
            .cornerRadius(NostosRadii.md)
            .overlay(
                RoundedRectangle(cornerRadius: NostosRadii.md)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dupGroupCardView(_ group: DuplicateGroupWithPhotos) -> some View {
        DupGroupCard(
            group: group,
            onKeepFirst: {
                if let first = group.photos.first,
                   let groupId = group.group.id,
                   let photoId = first.id {
                    state.setKeptPhoto(groupId: groupId, photoId: photoId)
                }
            },
            onKeepAll: {
                if let groupId = group.group.id {
                    state.setKeptAllInGroup(groupId: groupId)
                }
            },
            onClear: {
                if let groupId = group.group.id {
                    state.clearKeptInGroup(groupId: groupId)
                }
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

    private func keepAllInAllGroups() {
        for group in state.duplicateGroups {
            if let groupId = group.group.id {
                state.setKeptAllInGroup(groupId: groupId)
            }
        }
    }

    private func clearSelections() {
        for group in state.duplicateGroups {
            if let groupId = group.group.id {
                state.clearKeptInGroup(groupId: groupId)
            }
        }
    }
}

struct DupGroupCard: View {
    @EnvironmentObject var state: AppState
    let group: DuplicateGroupWithPhotos
    let onKeepFirst: () -> Void
    let onKeepAll: () -> Void
    let onClear: () -> Void

    var isResolved: Bool {
        group.photos.contains { $0.isKept }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider()
            thumbnailGrid
        }
        .background(Color.nostosSurface)
        .cornerRadius(NostosRadii.xl)
        .overlay(
            RoundedRectangle(cornerRadius: NostosRadii.xl)
                .stroke(isResolved ? Color.nostosGreen.opacity(0.45) : Color.nostosBorder, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var cardHeader: some View {
        HStack(spacing: NostosSpacing.sm) {
            // Type badge
            HStack(spacing: 5) {
                DiamondAccent(size: 5)
                Text(group.group.reason == .hashMatch ? "Exact" : "Near")
                    .font(.nostosLabel)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, NostosSpacing.sm)
            .padding(.vertical, 4)
            .background(group.group.reason == .hashMatch ? Color.nostosOrange : Color.nostosAccent)
            .cornerRadius(NostosRadii.sm)

            Text("\(group.photos.count) photos")
                .font(.nostosCaption)
                .foregroundColor(.nostosFg3)

            if isResolved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Resolved")
                        .font(.nostosLabel)
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundColor(.nostosGreen)
                .padding(.horizontal, NostosSpacing.sm)
                .padding(.vertical, 3)
                .background(Color.nostosGreen.opacity(0.1))
                .cornerRadius(NostosRadii.sm)
            }

            Spacer()

            // Action buttons
            HStack(spacing: NostosSpacing.xs) {
                cardActionButton(icon: "1.circle", color: .nostosGreen, help: "Keep first", action: onKeepFirst)
                    .accessibilityIdentifier("duplicateKeepFirstButton")
                cardActionButton(icon: "checkmark.circle", color: .nostosAccent, help: "Keep all", action: onKeepAll)
                    .accessibilityIdentifier("duplicateKeepAllButton")
                cardActionButton(icon: "xmark.circle", color: .nostosRed, help: "Clear selection", action: onClear)
                    .accessibilityIdentifier("duplicateClearGroupButton")
            }
        }
        .padding(.horizontal, NostosSpacing.lg)
        .padding(.vertical, NostosSpacing.md)
    }

    @ViewBuilder
    private func cardActionButton(icon: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var thumbnailGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: NostosSpacing.sm)],
            spacing: NostosSpacing.sm
        ) {
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
        .padding(NostosSpacing.lg)
    }
}

struct DupPhotoThumb: View {
    let photo: Photo
    let isKept: Bool
    let onKeep: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
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
                .frame(width: 90, height: 90)
                .clipped()
                .cornerRadius(NostosRadii.md)
                .overlay(
                    RoundedRectangle(cornerRadius: NostosRadii.md)
                        .stroke(isKept ? Color.nostosGreen : Color.nostosBorder, lineWidth: isKept ? 2 : 1)
                )
                .onTapGesture { onKeep() }
                .accessibilityIdentifier("duplicatePhotoTile")

                if isKept {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.nostosGreen)
                        .background(Color.nostosSurface.clipShape(Circle()))
                        .padding(3)
                }
            }

            Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(.nostosFg2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 90)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        Task.detached(priority: .userInitiated) {
            let loaded: NSImage?
            if let path = photo.thumbnailPath {
                loaded = await ThumbnailService.loadImageAsync(path: path)
            } else if let photoId = photo.id {
                let path = ThumbnailService.thumbnail(
                    for: photoId,
                    sourceURL: URL(fileURLWithPath: photo.path)
                )
                if let p = path {
                    loaded = await ThumbnailService.loadImageAsync(path: p)
                } else {
                    loaded = nil
                }
            } else {
                loaded = nil
            }
            await MainActor.run { image = loaded }
        }
    }
}
