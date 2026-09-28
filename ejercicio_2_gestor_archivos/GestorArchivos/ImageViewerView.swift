import SwiftUI

/// Visor de imagenes con zoom (gesto de pinza), rotacion y un boton
/// para volver a "ajustar a pantalla".
struct ImageViewerView: View {
    let url: URL

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var uiImage: UIImage? { UIImage(contentsOfFile: url.path) }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .rotationEffect(rotation)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in scale = max(0.5, lastScale * value) }
                                    .onEnded { _ in lastScale = scale },
                                RotationGesture()
                                    .onChanged { value in rotation = lastRotation + value }
                                    .onEnded { _ in lastRotation = rotation }
                            )
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                } else {
                    Text("No se pudo cargar la imagen")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Ajustar a pantalla") {
                    withAnimation {
                        scale = 1; lastScale = 1
                        rotation = .zero; lastRotation = .zero
                        offset = .zero; lastOffset = .zero
                    }
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}
