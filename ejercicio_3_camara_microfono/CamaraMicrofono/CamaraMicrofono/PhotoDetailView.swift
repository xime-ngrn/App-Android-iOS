import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack {
            if let uiImage = UIImage(contentsOfFile: item.fileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
            if let filter = item.filterUsed {
                Text("Filtro: \(filter)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Foto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("¿Eliminar esta foto?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                MediaStore.delete(item)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
