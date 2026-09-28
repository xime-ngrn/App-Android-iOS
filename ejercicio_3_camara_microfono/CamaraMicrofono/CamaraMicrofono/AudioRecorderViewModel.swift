import AVFoundation
import Combine

/// Controla la grabacion de audio con AVAudioRecorder: permisos,
/// inicio/paro de grabacion y cronometro en vivo.
final class AudioRecorderViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFileName: String?

    func requestPermissionAndRecord() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startRecording()
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startRecording()
                    } else {
                        self?.errorMessage = "Se necesita permiso de microfono para grabar."
                    }
                }
            }
        case .denied:
            errorMessage = "El acceso al microfono esta desactivado. Actívalo en Ajustes."
        @unknown default:
            break
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "No se pudo preparar el audio: \(error.localizedDescription)"
            return
        }

        let fileName = "audio_\(UUID().uuidString).m4a"
        currentFileName = fileName
        let url = MediaStore.capturesDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            isRecording = true
            elapsedTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.elapsedTime = self?.recorder?.currentTime ?? 0
            }
        } catch {
            errorMessage = "No se pudo iniciar la grabacion: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        if let fileName = currentFileName {
            MediaStore.registerAudio(fileName: fileName, duration: elapsedTime)
        }
        currentFileName = nil
    }
}

extension AudioRecorderViewModel: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        errorMessage = "Error de grabacion: \(error?.localizedDescription ?? "desconocido")"
    }
}
