import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_processing.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/photo_filter.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/app_database.dart';
import '../datasources/file_storage.dart';
import '../models/media_mapper.dart';
import '../services/location_service.dart';
import '../services/thumbnail_service.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({
    required AppDatabase database,
    required FileStorage storage,
    required ThumbnailService thumbnails,
    required LocationService location,
  })  : _database = database,
        _storage = storage,
        _thumbnails = thumbnails,
        _location = location;

  final AppDatabase _database;
  final FileStorage _storage;
  final ThumbnailService _thumbnails;
  final LocationService _location;

  Database get _sql => _database.db;

  // ---------------------------------------------------------------- captura

  @override
  String newTempPath(String extension) => _storage.tempFile('TMP', extension);

  @override
  Future<MediaItem> savePhoto({required String sourcePath, required PhotoFilter filter}) async {
    final id = _storage.newId();
    final now = DateTime.now();
    // La ubicación se pide en paralelo al procesamiento de la imagen.
    final locationFuture = _location.tryGetLocation();
    final fileName = 'IMG_$id.jpg';

    final File file;
    if (filter == PhotoFilter.original) {
      file = await _storage.moveInto(sourcePath, _storage.photos, fileName);
    } else {
      final raw = await File(sourcePath).readAsBytes();
      final processed = await ImageProcessing.applyEdits(raw, EditParams(matrix: filter.matrix));
      file = File(p.join(_storage.photos.path, fileName));
      await file.writeAsBytes(processed, flush: true);
      await _storage.deleteIfExists(sourcePath);
    }

    final thumb = await _thumbnails.create(file, id);
    final location = await locationFuture;
    final item = MediaItem(
      id: id,
      type: MediaType.photo,
      title: 'Foto ${formatDate(now)}',
      filePath: file.path,
      thumbnailPath: thumb,
      createdAt: now,
      latitude: location?.latitude,
      longitude: location?.longitude,
      filter: filter == PhotoFilter.original ? null : filter.name,
      sizeBytes: await file.length(),
    );
    await _insert(item);
    return item;
  }

  @override
  Future<MediaItem> saveAudio({required String sourcePath, required Duration duration}) async {
    final id = _storage.newId();
    final now = DateTime.now();
    final locationFuture = _location.tryGetLocation();
    final ext = p.extension(sourcePath).isEmpty ? '.m4a' : p.extension(sourcePath);
    final file = await _storage.moveInto(sourcePath, _storage.audio, 'AUD_$id$ext');
    final location = await locationFuture;
    final item = MediaItem(
      id: id,
      type: MediaType.audio,
      title: 'Audio ${formatDate(now)}',
      filePath: file.path,
      createdAt: now,
      latitude: location?.latitude,
      longitude: location?.longitude,
      duration: duration,
      sizeBytes: await file.length(),
    );
    await _insert(item);
    return item;
  }

  // --------------------------------------------------------------- consulta

  @override
  Future<List<MediaItem>> getMedia({MediaType? type, int? albumId, String? tag}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('m.type = ?');
      args.add(type.name);
    }
    if (albumId != null) {
      where.add('m.album_id = ?');
      args.add(albumId);
    }
    if (tag != null) {
      where.add('m.id IN (SELECT media_id FROM tags WHERE tag = ?)');
      args.add(tag);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await _sql.rawQuery('''
      SELECT m.*, GROUP_CONCAT(t.tag, ',') AS tags
      FROM media m
      LEFT JOIN tags t ON t.media_id = m.id
      $whereSql
      GROUP BY m.id
      ORDER BY m.created_at DESC
    ''', args);
    return rows.map((r) => MediaMapper.fromRow(r, _storage)).toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    final rows = await _sql.rawQuery('SELECT DISTINCT tag FROM tags ORDER BY tag COLLATE NOCASE');
    return rows.map((r) => r['tag'] as String).toList();
  }

  // ---------------------------------------------------------- modificación

  @override
  Future<void> updateMedia(MediaItem item) async {
    await _sql.transaction((txn) async {
      await txn.update(
        'media',
        {'title': item.title, 'album_id': item.albumId},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await _writeTags(txn, item.id, item.tags);
    });
  }

  @override
  Future<void> moveToAlbum(List<String> ids, int? albumId) async {
    if (ids.isEmpty) return;
    await _sql.rawUpdate(
      'UPDATE media SET album_id = ? WHERE id IN (${_placeholders(ids.length)})',
      [albumId, ...ids],
    );
  }

  @override
  Future<MediaItem> editPhoto(MediaItem item, EditParams params, {required bool asCopy}) async {
    final original = await File(item.filePath).readAsBytes();
    final edited = await ImageProcessing.applyEdits(original, params);
    final now = DateTime.now();
    final id = asCopy ? _storage.newId() : item.id;
    // Siempre se escribe con un nombre nuevo: así el caché de imágenes de
    // Flutter nunca muestra la versión anterior.
    final file = File(p.join(_storage.photos.path, 'IMG_${id}_e${now.millisecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(edited, flush: true);
    final thumb = await _thumbnails.create(file, id);

    if (asCopy) {
      final copy = item.copyWith(
        id: id,
        title: '${item.title} (editada)',
        filePath: file.path,
        thumbnailPath: thumb,
        createdAt: now,
        sizeBytes: edited.length,
      );
      await _insert(copy);
      return copy;
    }

    final updated = item.copyWith(filePath: file.path, thumbnailPath: thumb, sizeBytes: edited.length);
    await _sql.update(
      'media',
      {
        'file_path': _storage.toRelative(file.path),
        'thumb_path': thumb == null ? null : _storage.toRelative(thumb),
        'size_bytes': edited.length,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _storage.deleteIfExists(item.filePath);
    return updated;
  }

  @override
  Future<void> deleteMedia(List<MediaItem> items) async {
    if (items.isEmpty) return;
    final ids = items.map((e) => e.id).toList();
    await _sql.delete('media', where: 'id IN (${_placeholders(ids.length)})', whereArgs: ids);
    for (final item in items) {
      await _storage.deleteIfExists(item.filePath);
      await _storage.deleteIfExists(item.thumbnailPath);
      _thumbnails.evict(item.thumbnailPath);
    }
  }

  // ---------------------------------------------------------------- álbumes

  @override
  Future<List<Album>> getAlbums() async {
    final rows = await _sql.rawQuery('''
      SELECT a.id, a.name, a.created_at, COUNT(m.id) AS item_count
      FROM albums a
      LEFT JOIN media m ON m.album_id = a.id
      GROUP BY a.id
      ORDER BY a.name COLLATE NOCASE
    ''');
    return rows
        .map((r) => Album(
              id: r['id'] as int,
              name: r['name'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
              itemCount: r['item_count'] as int,
            ))
        .toList();
  }

  @override
  Future<Album> createAlbum(String name) async {
    final clean = await _validateAlbumName(name);
    final now = DateTime.now();
    final id = await _sql.insert('albums', {'name': clean, 'created_at': now.millisecondsSinceEpoch});
    return Album(id: id, name: clean, createdAt: now);
  }

  @override
  Future<void> renameAlbum(int id, String name) async {
    final clean = await _validateAlbumName(name, ignoreId: id);
    await _sql.update('albums', {'name': clean}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAlbum(int id) async {
    // ON DELETE SET NULL deja el contenido "sin álbum" en vez de borrarlo.
    await _sql.delete('albums', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------- exportar / importar

  @override
  Future<String> exportArchive(List<MediaItem> items) async {
    if (items.isEmpty) throw const AppException('No hay elementos para exportar');
    final albumNames = {for (final a in await getAlbums()) a.id: a.name};
    final archive = Archive();
    final manifestItems = <Map<String, Object?>>[];

    for (final item in items) {
      final file = File(item.filePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final entry = 'files/${p.basename(item.filePath)}';
      archive.addFile(ArchiveFile(entry, bytes.length, bytes));
      manifestItems.add(MediaMapper.toManifest(item, entry, albumNames[item.albumId]));
    }

    final manifest = utf8.encode(const JsonEncoder.withIndent('  ').convert({
      'format': 'cammic-export',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': manifestItems,
    }));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

    final List<int> zipped = ZipEncoder().encode(archive);
if (zipped.isEmpty) throw const AppException('No se pudo generar el ZIP');
    final out = File(_storage.tempFile('CamMic_export', 'zip'));
    await out.writeAsBytes(zipped, flush: true);
    return out.path;
  }

  @override
  Future<int> importArchive(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const AppException('El archivo no es un ZIP válido');
    }
    final entries = <String, ArchiveFile>{
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };
    final manifestEntry = entries['manifest.json'];
    if (manifestEntry == null) {
      throw const AppException('El ZIP no es una exportación de CamMic (falta manifest.json)');
    }
    final manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>)) as Map<String, dynamic>;
    final rawItems = (manifest['items'] as List?) ?? const [];

    final existing = (await _sql.query('media', columns: ['id'])).map((r) => r['id'] as String).toSet();
    final albumCache = <String, int>{};
    var imported = 0;

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final id = m['id'] as String? ?? _storage.newId();
      if (existing.contains(id)) continue; // ya estaba: no se duplica
      final entry = entries[m['file']];
      if (entry == null) continue;

      final isAudio = m['type'] == MediaType.audio.name;
      final dir = isAudio ? _storage.audio : _storage.photos;
      // basename evita "zip slip" (rutas maliciosas dentro del ZIP).
      final name = await _storage.uniqueName(dir, p.basename(entry.name));
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(entry.content as List<int>, flush: true);
      final thumb = isAudio ? null : await _thumbnails.create(file, id);

      int? albumId;
      final albumName = (m['album'] as String?)?.trim();
      if (albumName != null && albumName.isNotEmpty) {
        albumId = albumCache[albumName] ??= await _findOrCreateAlbum(albumName);
      }
      final durationMs = (m['durationMs'] as num?)?.toInt();
      final createdMs = (m['createdAt'] as num?)?.toInt();

      final item = MediaItem(
        id: id,
        type: isAudio ? MediaType.audio : MediaType.photo,
        title: m['title'] as String? ?? name,
        filePath: file.path,
        thumbnailPath: thumb,
        createdAt: createdMs == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(createdMs),
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        tags: ((m['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        albumId: albumId,
        duration: durationMs == null ? null : Duration(milliseconds: durationMs),
        filter: m['filter'] as String?,
        sizeBytes: await file.length(),
      );
      await _insert(item);
      existing.add(id);
      imported++;
    }
    return imported;
  }

  // ---------------------------------------------------------- almacenamiento

  @override
  Future<int> storageUsageBytes() => _storage.usageBytes();

  @override
  Future<void> rebuildThumbnails() async {
    _thumbnails.clearMemory();
    final rows = await _sql.query(
      'media',
      columns: ['id', 'file_path'],
      where: 'type = ?',
      whereArgs: [MediaType.photo.name],
    );
    for (final r in rows) {
      final file = File(_storage.toAbsolute(r['file_path'] as String));
      if (!await file.exists()) continue;
      final thumb = await _thumbnails.create(file, r['id'] as String);
      await _sql.update(
        'media',
        {'thumb_path': thumb == null ? null : _storage.toRelative(thumb)},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _insert(MediaItem item) async {
    await _sql.transaction((txn) async {
      await txn.insert('media', MediaMapper.toRow(item, _storage),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _writeTags(txn, item.id, item.tags);
    });
  }

  Future<void> _writeTags(DatabaseExecutor executor, String mediaId, List<String> tags) async {
    await executor.delete('tags', where: 'media_id = ?', whereArgs: [mediaId]);
    final batch = executor.batch();
    for (final tag in tags.toSet()) {
      batch.insert('tags', {'media_id': mediaId, 'tag': tag});
    }
    await batch.commit(noResult: true);
  }

  Future<String> _validateAlbumName(String name, {int? ignoreId}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('El nombre del álbum no puede estar vacío');
    final rows = await _sql.query('albums',
        columns: ['id'], where: 'name = ? COLLATE NOCASE', whereArgs: [clean], limit: 1);
    if (rows.isNotEmpty && rows.first['id'] != ignoreId) {
      throw AppException('Ya existe un álbum llamado "$clean"');
    }
    return clean;
  }

  Future<int> _findOrCreateAlbum(String name) async {
    final rows = await _sql.query('albums',
        columns: ['id'], where: 'name = ? COLLATE NOCASE', whereArgs: [name], limit: 1);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return _sql.insert('albums', {'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  String _placeholders(int n) => List.filled(n, '?').join(',');
}
