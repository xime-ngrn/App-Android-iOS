import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Maneja los directorios de la app:
///   Documents/media/photos      → fotos
///   Documents/media/audio       → grabaciones
///   Documents/media/thumbnails  → miniaturas (caché en disco)
///   tmp/cammic                  → archivos temporales y exportaciones
///
/// En la BD se guardan rutas RELATIVAS: en iOS la ruta absoluta del
/// contenedor cambia al reinstalar/actualizar la app.
class FileStorage {
  late final Directory root;
  late final Directory photos;
  late final Directory audio;
  late final Directory thumbnails;
  late final Directory temp;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();
    root = Directory(p.join(docs.path, 'media'));
    photos = Directory(p.join(root.path, 'photos'));
    audio = Directory(p.join(root.path, 'audio'));
    thumbnails = Directory(p.join(root.path, 'thumbnails'));
    temp = Directory(p.join(tmp.path, 'cammic'));
    for (final dir in [photos, audio, thumbnails, temp]) {
      await dir.create(recursive: true);
    }
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String toAbsolute(String relative) => p.join(root.path, relative);
  String toRelative(String absolute) => p.relative(absolute, from: root.path);

  String tempFile(String prefix, String extension) =>
      p.join(temp.path, '${prefix}_${newId()}.$extension');

  /// Mueve (o copia si está en otro volumen) un archivo al directorio destino.
  Future<File> moveInto(String sourcePath, Directory dir, String fileName) async {
    final target = p.join(dir.path, fileName);
    final source = File(sourcePath);
    try {
      return await source.rename(target);
    } on FileSystemException {
      final copy = await source.copy(target);
      await deleteIfExists(sourcePath);
      return copy;
    }
  }

  Future<String> uniqueName(Directory dir, String fileName) async {
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var candidate = fileName;
    var i = 1;
    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '${base}_$i$ext';
      i++;
    }
    return candidate;
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un archivo huérfano no debe romper el flujo del usuario.
    }
  }

  Future<int> usageBytes() async {
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
