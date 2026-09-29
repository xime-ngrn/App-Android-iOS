import '../../core/utils/image_processing.dart';
import '../entities/album.dart';
import '../entities/media_item.dart';
import '../entities/photo_filter.dart';

/// Contrato del repositorio. La capa de presentación y los casos de uso solo
/// conocen esta interfaz; la implementación vive en la capa de datos.
abstract interface class MediaRepository {
  String newTempPath(String extension);

  Future<MediaItem> savePhoto({required String sourcePath, required PhotoFilter filter});
  Future<MediaItem> saveAudio({required String sourcePath, required Duration duration});

  Future<List<MediaItem>> getMedia({MediaType? type, int? albumId, String? tag});
  Future<List<String>> getAllTags();
  Future<void> updateMedia(MediaItem item);
  Future<void> moveToAlbum(List<String> ids, int? albumId);
  Future<MediaItem> editPhoto(MediaItem item, EditParams params, {required bool asCopy});
  Future<void> deleteMedia(List<MediaItem> items);

  Future<List<Album>> getAlbums();
  Future<Album> createAlbum(String name);
  Future<void> renameAlbum(int id, String name);
  Future<void> deleteAlbum(int id);

  Future<String> exportArchive(List<MediaItem> items);
  Future<int> importArchive(String zipPath);

  Future<int> storageUsageBytes();
  Future<void> rebuildThumbnails();
}
