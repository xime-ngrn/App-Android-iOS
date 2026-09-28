# Cámara y Micrófono — Ejercicio 3

Archivos Swift/SwiftUI para la app de cámara y micrófono nativa de iPhone.

## Qué hace cada archivo

- `CamaraMicrofonoApp.swift` — punto de entrada de la app (inicializa Core Data).
- `ContentView.swift` — pestañas: Cámara, Audio, Galería.
- `CameraViewModel.swift` — maneja AVCaptureSession: permisos, flash, timer, captura de fotos.
- `CameraPreviewView.swift` — puente UIKit/SwiftUI para mostrar el visor de la cámara en vivo.
- `CameraView.swift` — pantalla de cámara: visor, filtro, flash, timer, botón de captura. Si el dispositivo no tiene cámara física (como el Simulador de iOS), muestra un selector de fotos (PHPicker) como alternativa.
- `PhotoFilters.swift` — filtros de Core Image (Original, Blanco y Negro, Sepia, Vívido).
- `AudioRecorderViewModel.swift` — maneja AVAudioRecorder: permisos, grabación, cronómetro.
- `AudioRecorderView.swift` — pantalla para grabar audio.
- `AudioPlayerViewModel.swift` — maneja AVAudioPlayer para reproducir grabaciones.
- `AudioDetailView.swift` — pantalla de reproducción de un audio guardado.
- `PhotoDetailView.swift` — pantalla de una foto guardada (con su filtro y fecha).
- `GalleryView.swift` — pestaña de galería: cuadrícula con todas las fotos/audios capturados, leídos de Core Data, y selector de tema.
- `MediaItem.swift` — entidad de Core Data (registro de una foto o audio).
- `MediaStore.swift` — guarda los archivos reales en el sandbox (Documents/Capturas) y crea/borra su registro en Core Data.
- `PersistenceController.swift` — stack de Core Data. El modelo se construye por código (no hace falta archivo .xcdatamodeld, así que no hay que crear nada extra en Xcode para esto).
- `AppSettings.swift` — estado persistente: tema (Guinda/Azul).
- `AppTheme.swift` — temas Guinda (IPN) y Azul (ESCOM).

## Cómo agregarlos a un proyecto de Xcode

1. Crea un proyecto nuevo en Xcode: **App**, pestaña **iOS** (no macOS), SwiftUI, Swift, nómbralo `CamaraMicrofono`, guárdalo dentro de `ejercicio_3_camara_microfono/` en el repositorio.
   - En el diálogo de guardar: **desmarca "Create Git repository on my Mac"**.
   - Si aparece la opción "Rename Target: Automatic", déjala **sin marcar** (no importa si el archivo de entrada por defecto se llama distinto, lo vamos a borrar).
2. Verifica en el proyecto → target → pestaña **General** → **Supported Destinations**, que **iPhone** esté en la lista (agrégalo con `+` si no aparece).
3. Borra los archivos por defecto que trae Xcode (`ContentView.swift` y el archivo con `@main`, sea cual sea su nombre).
4. Arrastra TODOS los archivos `.swift` de esta carpeta al panel de navegación de Xcode, marcando **"Copy items if needed"** y asegurándote de que el checkbox del target esté marcado.
5. En la configuración del proyecto (target → pestaña **Info**), agrega estas claves (necesarias para pedir permiso de cámara y micrófono):
   - `NSCameraUsageDescription` → algo como "Necesitamos acceso a la cámara para tomar fotos."
   - `NSMicrophoneUsageDescription` → algo como "Necesitamos acceso al micrófono para grabar audio."
6. Selecciona un simulador de **iPhone** (no "My Mac") y compila (`⌘B`).
7. Corre la app (▶️).

## Notas importantes al probar

- El **Simulador de iOS no tiene cámara física** — es normal y esperado. La app lo detecta sola y muestra el selector de fotos (PHPicker) en su lugar, tal como permite el ejercicio.
- El **micrófono del Simulador sí funciona** (usa el micrófono de tu Mac), así que la grabación de audio se puede probar de forma normal ahí mismo.
- La primera vez que grabes audio, el Simulador (o tu Mac) puede pedir permiso de micrófono — acéptalo.
