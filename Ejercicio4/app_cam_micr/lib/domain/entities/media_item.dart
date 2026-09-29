enum MediaType { photo, audio }

/// Entidad de dominio: un archivo capturado más sus metadatos.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    required this.filePath,
    required this.createdAt,
    this.thumbnailPath,
    this.latitude,
    this.longitude,
    this.tags = const [],
    this.albumId,
    this.duration,
    this.filter,
    this.sizeBytes = 0,
  });

  final String id;
  final MediaType type;
  final String title;
  final String filePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final List<String> tags;
  final int? albumId;
  final Duration? duration;
  final String? filter;
  final int sizeBytes;

  bool get isPhoto => type == MediaType.photo;
  bool get hasLocation => latitude != null && longitude != null;

  MediaItem copyWith({
    String? id,
    String? title,
    String? filePath,
    String? thumbnailPath,
    DateTime? createdAt,
    List<String>? tags,
    int? albumId,
    bool clearAlbum = false,
    int? sizeBytes,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude,
      longitude: longitude,
      tags: tags ?? this.tags,
      albumId: clearAlbum ? null : (albumId ?? this.albumId),
      duration: duration,
      filter: filter,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
