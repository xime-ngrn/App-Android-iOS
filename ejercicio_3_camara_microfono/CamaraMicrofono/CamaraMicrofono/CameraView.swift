import SwiftUI
import PhotosUI

/// Pantalla de camara. Si el dispositivo tiene camara fisica, muestra
/// el visor en vivo con controles de flash, timer y filtro. Si no (por
/// ejemplo en el Simulador de iOS, que no tiene camara), muestra un
/// selector de fotos (PHPicker) como alternativa, tal como permite el
/// ejercicio.
struct CameraView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = CameraViewModel()
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isCameraAvailable {
                    CameraPreviewView(session: viewModel.session)
                        .ignoresSafeArea()
                        .onAppear { viewModel.requestPermissionAndStart() }
                        .onDisappear { viewModel.stopSession() }

                    if let countdown = viewModel.countdown {
                        Text("\(countdown)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 10)
                    }

                    VStack {
                        Spacer()
                        controlsBar
                    }
                } else {
                    unavailableCameraFallback
                }
            }
            .navigationTitle("Cámara")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Aviso", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $viewModel.capturedImage) { wrapped in
                capturedPreview(wrapped.image)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let filter = viewModel.selectedFilter
                        let filtered = filter.apply(to: image)
                        MediaStore.savePhoto(filtered, filterUsed: filter == .original ? nil : filter.rawValue)
                        await MainActor.run {
                            viewModel.capturedImage = IdentifiableImage(image: filtered)
                        }
                    }
                }
            }
        }
    }

    private var controlsBar: some View {
        VStack(spacing: 16) {
            Picker("Filtro", selection: $viewModel.selectedFilter) {
                ForEach(PhotoFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .colorScheme(.dark)

            HStack(spacing: 40) {
                Button {
                    viewModel.flashMode = viewModel.flashMode == .off ? .on : .off
                } label: {
                    Image(systemName: viewModel.flashMode == .on ? "bolt.fill" : "bolt.slash")
                        .font(.title2)
                }

                Button {
                    viewModel.capturePhoto()
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(.white.opacity(0.2)))
                }

                Menu {
                    Button("Sin timer") { viewModel.timerSeconds = 0 }
                    Button("3 segundos") { viewModel.timerSeconds = 3 }
                    Button("10 segundos") { viewModel.timerSeconds = 10 }
                } label: {
                    Image(systemName: "timer")
                        .font(.title2)
                }
            }
            .foregroundStyle(.white)
            .padding(.bottom, 24)
        }
        .padding(.top, 12)
        .background(.black.opacity(0.35))
    }

    private var unavailableCameraFallback: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Este dispositivo no tiene camara disponible (normal en el Simulador de iOS).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Picker("Filtro", selection: $viewModel.selectedFilter) {
                ForEach(PhotoFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Button {
                showPhotoPicker = true
            } label: {
                Label("Elegir foto de la galería", systemImage: "photo.on.rectangle")
                    .padding()
                    .background(settings.theme.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    @ViewBuilder
    private func capturedPreview(_ image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
            Text("Guardada en la galería de la app")
                .foregroundStyle(.secondary)
            Button("Cerrar") { viewModel.capturedImage = nil }
                .padding()
        }
    }
}
