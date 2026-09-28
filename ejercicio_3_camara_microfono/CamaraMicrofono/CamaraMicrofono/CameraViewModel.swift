import AVFoundation
import UIKit
import Combine

/// Envoltorio para poder usar UIImage con .sheet(item:), ya que UIImage
/// no es Equatable/Identifiable por si solo.
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Controla la sesion de camara (AVCaptureSession): permisos, flash,
/// timer y captura de fotos con el filtro seleccionado. Si el
/// dispositivo no tiene camara fisica (como el Simulador de iOS),
/// isCameraAvailable queda en false y la vista debe usar el selector
/// de fotos (PHPicker) como alternativa.
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var timerSeconds: Int = 0 // 0, 3, 10
    @Published var selectedFilter: PhotoFilter = .original
    @Published var countdown: Int?
    @Published var errorMessage: String?
    @Published var capturedImage: IdentifiableImage?
    let isCameraAvailable: Bool = AVCaptureDevice.default(for: .video) != nil

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    func requestPermissionAndStart() {
        guard isCameraAvailable else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSessionIfNeeded()
                    } else {
                        self?.errorMessage = "Se necesita permiso de camara para continuar."
                    }
                }
            }
        default:
            errorMessage = "El acceso a la camara esta desactivado. Actívalo en Ajustes."
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else {
            startSession()
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            errorMessage = "No se pudo acceder a la camara."
            return
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
        startSession()
    }

    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto() {
        guard timerSeconds == 0 else {
            countdown = timerSeconds
            tickCountdown()
            return
        }
        performCapture()
    }

    private func tickCountdown() {
        guard let remaining = countdown else { return }
        if remaining <= 0 {
            countdown = nil
            performCapture()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, let current = self.countdown else { return }
            self.countdown = current - 1
            self.tickCountdown()
        }
    }

    private func performCapture() {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            DispatchQueue.main.async { self.errorMessage = "Error al capturar: \(error.localizedDescription)" }
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        let filterUsed = selectedFilter
        let filtered = filterUsed.apply(to: image)
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = IdentifiableImage(image: filtered)
            MediaStore.savePhoto(filtered, filterUsed: filterUsed == .original ? nil : filterUsed.rawValue)
        }
    }
}
