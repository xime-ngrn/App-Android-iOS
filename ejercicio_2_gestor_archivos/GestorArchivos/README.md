# Gestor de Archivos — Ejercicio 2
Archivos Swift/SwiftUI para el gestor de archivos de iPhone.

## Qué hace cada archivo

- `GestorArchivosApp.swift` — punto de entrada de la app.
- `ContentView.swift` — pestañas: Archivos, Favoritos, Recientes.
- `RootFoldersView.swift` — pantalla de inicio con los 3 directorios del sandbox (Documents, Inbox, tmp) y el selector de tema.
- `FileBrowserView.swift` — pantalla principal de exploración: lista, búsqueda, orden, crear carpeta, importar, renombrar, duplicar, eliminar, favoritos, compartir, gestos (deslizar, mantener presionado, deslizar hacia abajo para actualizar).
- `FileBrowserViewModel.swift` — lógica de FileManager (listar, crear, copiar, mover/renombrar, eliminar, importar).
- `FileItem.swift` — modelo de un archivo/carpeta, con ícono según su tipo (UTType).
- `FileRowView.swift` — fila de la lista, con miniatura para imágenes.
- `ImageViewerView.swift` — visor de imágenes con zoom, rotación y reajuste.
- `TextFileViewerView.swift` — visor de archivos de texto.
- `QuickLookPreview.swift` — vista previa nativa (Quick Look) para otros tipos de archivo.
- `DocumentPicker.swift` — importar desde la app Archivos / iCloud Drive.
- `ShareSheet.swift` — hoja de compartir del sistema.
- `ThumbnailCache.swift` — caché en memoria de miniaturas de imágenes.
- `AppSettings.swift` — estado persistente: tema, favoritos, recientes, última carpeta (UserDefaults).
- `AppTheme.swift` — temas Guinda (IPN) y Azul (ESCOM).
- `FavoritesRecentsViews.swift` — pestañas de Favoritos y Recientes.

## Cómo agregarlos a un proyecto de Xcode

1. Crea un proyecto nuevo en Xcode: App, SwiftUI, Swift, nómbralo `GestorArchivos`, guárdalo dentro de `ejercicio_2_gestor_archivos/` en el repositorio.
2. Borra los archivos `ContentView.swift` y el archivo `...App.swift` que Xcode generó por defecto (los vamos a reemplazar).
3. Arrastra TODOS los archivos `.swift` de esta carpeta al panel de navegación de Xcode (dentro del grupo del proyecto), asegurándote de marcar "Copy items if needed" y que el target de la app esté marcado.
4. En la configuración del proyecto (target > pestaña **Info**), agrega estas dos claves (necesarias para que los archivos de la app aparezcan en la app Archivos de iOS):
   - `UIFileSharingEnabled` = `YES`
   - `LSSupportsOpeningDocumentsInPlace` = `YES`
5. En **Info**, agrega también las descripciones de uso si compilas junto con cámara/micrófono más adelante (Ejercicio 3):
   - `NSCameraUsageDescription`
   - `NSMicrophoneUsageDescription`
6. Compila y corre en el simulador de iPhone.
