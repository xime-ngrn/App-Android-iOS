import '../../domain/entities/media_item.dart';
import '../datasources/file_storage.dart';

/// Convierte entre filas SQLite / JSON de exportación y entidades de dominio.
class MediaMapper {
  MediaMapper._();

  static MediaItem fromRow(Map<String, Object?> row, FileStorage storage) {
    final thumb = row['thumb_path'] as String?;
    final durationMs = row['duration_ms'] as int?;
    final rawTags = row['tags'] as String?;
    return MediaItem(
      id: row['id'] as String,
      type: row['type'] == MediaType.audio.name ? MediaType.audio : MediaType.photo,
      title: row['title'] as String,
      filePath: storage.toAbsolute(row['file_path'] as String),
      thumbnailPath: thumb == null ? null : storage.toAbsolute(thumb),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      tags: rawTags == null
          ? const <String>[]
          : (rawTags.split(',').where((t) => t.isNotEmpty).toList()..sort()),
      albumId: row['album_id'] as int?,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      filter: row['filter'] as String?,
      sizeBytes: (row['size_bytes'] as int?) ?? 0,
    );
  }

  static Map<String, Object?> toRow(MediaItem item, FileStorage storage) {
    final thumb = item.thumbnailPath;
    return {
      'id': item.id,
      'type': item.type.name,
      'title': item.title,
      'file_path': storage.toRelative(item.filePath),
      'thumb_path': thumb == null ? null : storage.toRelative(thumb),
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'latitude': item.latitude,
      'longitude': item.longitude,
      'album_id': item.albumId,
      'duration_ms': item.duration?.inMilliseconds,
      'filter': item.filter,
      'size_bytes': item.sizeBytes,
    };
  }

  static Map<String, Object?> toManifest(MediaItem item, String archiveEntry, String? albumName) => {
        'id': item.id,
        'type': item.type.name,
        'title': item.title,
        'file': archiveEntry,
        'createdAt': item.createdAt.millisecondsSinceEpoch,
        'latitude': item.latitude,
        'longitude': item.longitude,
        'tags': item.tags,
        'album': albumName,
        'durationMs': item.duration?.inMilliseconds,
        'filter': item.filter,
      };
}
