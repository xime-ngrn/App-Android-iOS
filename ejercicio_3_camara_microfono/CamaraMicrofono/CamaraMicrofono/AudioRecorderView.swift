import SwiftUI

struct AudioRecorderView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = AudioRecorderViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(settings.theme.accentColor)

                Text(formattedTime(viewModel.elapsedTime))
                    .font(.system(size: 40, weight: .medium, design: .monospaced))

                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.requestPermissionAndRecord()
                    }
                } label: {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : settings.theme.accentColor)
                        .frame(width: 84, height: 84)
                        .overlay {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .foregroundStyle(.white)
                                .font(.title)
                        }
                }
                Spacer()
            }
            .navigationTitle("Grabar Audio")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Aviso", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
