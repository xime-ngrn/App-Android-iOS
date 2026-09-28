import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Equatable, Hashable {
    let id: String // ruta completa, unica
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var utType: UTType? {
        UTType(filenameExtension: url.pathExtension)
    }

    var isImage: Bool {
        guard let type = utType else { return false }
        return type.conforms(to: .image)
    }

    var isText: Bool {
        guard let type = utType else { return false }
        return type.conforms(to: .plainText) || type.conforms(to: .sourceCode) || type.conforms(to: .json)
    }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        guard let type = utType else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if isText { return "doc.text" }
        return "doc"
    }

    var formattedSize: String {
        if isDirectory { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
