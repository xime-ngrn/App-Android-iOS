import SwiftUI
import UniformTypeIdentifiers

struct FileRowView: View {
    let item: FileItem
    let isFavorite: Bool

    private var thumbnail: Image? {
        guard item.isImage, let uiImage = ThumbnailCache.shared.thumbnail(for: item.url) else { return nil }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: item.iconName)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !item.isDirectory {
                        Text(item.formattedSize)
                    }
                    Text(item.modificationDate, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}
