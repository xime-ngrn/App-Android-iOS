import SwiftUI

struct AudioDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    @StateObject private var player = AudioPlayerViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(item.createdAt, style: .date)
                .foregroundStyle(.secondary)

            Text(formattedTime(player.currentTime) + " / " + formattedTime(player.duration))
                .font(.system(.body, design: .monospaced))

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }
        }
        .padding()
        .navigationTitle("Audio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { player.load(url: item.fileURL) }
        .onDisappear { player.stop() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("¿Eliminar este audio?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                MediaStore.delete(item)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
