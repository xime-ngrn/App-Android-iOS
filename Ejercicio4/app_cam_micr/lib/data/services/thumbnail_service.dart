import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/utils/image_processing.dart';
import '../datasources/file_storage.dart';

/// Miniaturas en dos niveles:
///  1. Disco (Documents/media/thumbnails): se generan una sola vez al guardar.
///  2. Memoria (LRU): la galería no vuelve a leer disco al hacer scroll.
class ThumbnailService {
  ThumbnailService(this._storage);

  final FileStorage _storage;
  static const int _maxEntries = 200;

  // Map literal = LinkedHashMap: conserva orden de inserción → LRU sencillo.
  final Map<String, Uint8List> _memory = <String, Uint8List>{};
  final Map<String, Future<Uint8List?>> _pending = <String, Future<Uint8List?>>{};

  int get cachedCount => _memory.length;

  Future<String?> create(File source, String id) async {
    final bytes = await source.readAsBytes();
    final data = await ImageProcessing.thumbnail(bytes);
    if (data == null) return null;
    final path = p.join(_storage.thumbnails.path, 'TH_$id.jpg');
    await File(path).writeAsBytes(data, flush: true);
    _put(path, data);
    return path;
  }

  /// Lectura síncrona desde memoria (evita parpadeos al reconstruir).
  Uint8List? peek(String path) {
    final hit = _memory.remove(path);
    if (hit != null) _memory[path] = hit; // se vuelve la más reciente
    return hit;
  }

  Future<Uint8List?> load(String path) {
    final hit = peek(path);
    if (hit != null) return Future<Uint8List?>.value(hit);
    // Deduplica lecturas concurrentes del mismo archivo.
    return _pending.putIfAbsent(path, () async {
      try {
        final file = File(path);
        if (!await file.exists()) return null;
        final bytes = await file.readAsBytes();
        _put(path, bytes);
        return bytes;
      } finally {
        _pending.remove(path);
      }
    });
  }

  void evict(String? path) {
    if (path != null) _memory.remove(path);
  }

  void clearMemory() => _memory.clear();

  void _put(String path, Uint8List data) {
    _memory.remove(path);
    _memory[path] = data;
    while (_memory.length > _maxEntries) {
      _memory.remove(_memory.keys.first);
    }
  }
}
