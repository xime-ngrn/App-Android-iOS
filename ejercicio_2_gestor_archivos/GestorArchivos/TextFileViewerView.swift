import SwiftUI

/// Visor simple de archivos de texto (.txt, .md, .swift, .json, etc).
struct TextFileViewerView: View {
    let url: URL
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            content = (try? String(contentsOf: url, encoding: .utf8))
                ?? "No se pudo leer este archivo como texto plano."
        }
    }
}
