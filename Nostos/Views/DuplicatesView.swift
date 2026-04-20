import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NostosPageHeader(
                title: "Duplicates",
                subtitle: "\(state.duplicateGroups.count) groups · \(totalPhotos) photos"
            )

            if state.duplicateGroups.isEmpty {
                EmptyStateView(
                    title: "No Duplicates Found",
                    systemImage: "checkmark.seal",
                    description: Text("Run a scan to detect duplicate photos.")
                )
                .background(NostosTheme.bg)
            } else {
                ZStack(alignment: .topLeading) {
                    NostosTheme.bg.ignoresSafeArea()
                    StarDotBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 280), spacing: 8)],
                                spacing: 8
                            ) {
                                ForEach(Array(state.duplicateGroups.enumerated()), id: \.element.id) { _, group in
                                    DuplicateGroupCard(group: group)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                            // Footer actions
                            HStack(spacing: 10) {
                                Button("Keep First in All Groups") {
                                    for group in state.duplicateGroups {
                                        if let gId = group.group.id,
                                           let first = group.photos.first,
                                           let pId = first.id {
                                            state.setKeptPhoto(groupId: gId, photoId: pId)
                                        }
                                    }
                                }
                                .buttonStyle(NostosButtonStyle(variant: .bordered))

                                let resolved = state.duplicateGroups.filter { g in
                                    g.photos.contains { $0.isKept }
                                }.count
                                Button("Clear Selections") {
                                    // resetting isn't directly supported; no-op in UI
                                }
                                .buttonStyle(NostosButtonStyle(variant: .danger))
                                .disabled(resolved == 0)

                                Spacer()

                                let canRemove = resolved == state.duplicateGroups.count
                                let dupsToRemove = totalPhotos - state.duplicateGroups.count
                                Button("Remove \(dupsToRemove) Duplicates") { }
                                    .buttonStyle(NostosButtonStyle(variant: .primary))
                                    .disabled(!canRemove)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .overlay(alignment: .top) {
                                Rectangle().fill(NostosTheme.border).frame(height: 1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var totalPhotos: Int {
        state.duplicateGroups.reduce(0) { $0 + $1.photos.count }
    }
}

// MARK: - DuplicateGroupCard

struct DuplicateGroupCard: View {
    @EnvironmentObject var state: AppState
    let group: DuplicateGroupWithPhotos
    @State private var expanded = false

    private var isResolved: Bool {
        group.photos.contains { $0.isKept }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                // Match type badge
                let isExact = group.group.reason == .hashMatch
                HStack(spacing: 4) {
                    DiamondAccent(color: isExact ? NostosTheme.orange : NostosTheme.accent, size: 4)
                    Text(isExact ? "Exact" : "Near")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isExact ? NostosTheme.orange : NostosTheme.accent)
                }
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill((isExact ? NostosTheme.orange : NostosTheme.accent).opacity(0.1))
                )

                Text("\(group.photos.count) photos")
                    .font(.system(size: 10))
                    .foregroundColor(NostosTheme.fg3)

                Spacer()

                if isResolved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(NostosTheme.green)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(NostosTheme.fg3)
                        .frame(width: 18, height: 18)
                        .background(NostosTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(NostosTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Thumbnails
            let thumbSize: CGFloat = expanded ? 86 : 52
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(group.photos) { photo in
                        DuplicateThumb(
                            photo: photo,
                            size: thumbSize,
                            showLabel: expanded,
                            onKeep: {
                                if let gId = group.group.id, let pId = photo.id {
                                    state.setKeptPhoto(groupId: gId, photoId: pId)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NostosTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isResolved ? NostosTheme.green.opacity(0.45) : NostosTheme.border, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - DuplicateThumb

private struct DuplicateThumb: View {
    let photo: Photo
    let size: CGFloat
    let showLabel: Bool
    let onKeep: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        Rectangle()
                            .fill(NostosTheme.surface2)
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(photo.isKept ? NostosTheme.green : NostosTheme.borderFaint,
                                lineWidth: photo.isKept ? 2.5 : 2)
                        .padding(photo.isKept ? -1 : -1)
                )
                .shadow(color: photo.isKept ? NostosTheme.green.opacity(0.2) : .clear,
                        radius: 4, x: 0, y: 0)
                .onTapGesture { if !photo.isKept { onKeep() } }
                .accessibilityIdentifier("duplicatePhotoTile")

                if photo.isKept {
                    Circle()
                        .fill(NostosTheme.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .padding(3)
                }
            }

            if showLabel {
                Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                    .font(.system(size: 8))
                    .foregroundColor(NostosTheme.fg3)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: size)
            }
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        let tp = photo.thumbnailPath; let lp = photo.path; let lid = photo.id
        Task.detached(priority: .userInitiated) {
            let p: String? = {
                if let t = tp { return t }
                if let id = lid {
                    return ThumbnailService.thumbnail(for: id, sourceURL: URL(fileURLWithPath: lp))
                }
                return nil
            }()
            await MainActor.run { if let p { image = ThumbnailService.loadImage(path: p) } }
        }
    }
}
