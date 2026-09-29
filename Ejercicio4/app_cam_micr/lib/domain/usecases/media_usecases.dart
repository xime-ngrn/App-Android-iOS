import '../../core/utils/image_processing.dart';
import '../entities/album.dart';
import '../entities/media_item.dart';
import '../entities/photo_filter.dart';
import '../repositories/media_repository.dart';

class CapturePhoto {
  const CapturePhoto(this._repo);
  final MediaRepository _repo;

  Future<MediaItem> call({required String sourcePath, PhotoFilter filter = PhotoFilter.original}) =>
      _repo.savePhoto(sourcePath: sourcePath, filter: filter);
}

class SaveRecording {
  const SaveRecording(this._repo);
  final MediaRepository _repo;

  String tempPath() => _repo.newTempPath('m4a');

  Future<MediaItem> call({required String sourcePath, required Duration duration}) =>
      _repo.saveAudio(sourcePath: sourcePath, duration: duration);
}

class LoadGallery {
  const LoadGallery(this._repo);
  final MediaRepository _repo;

  Future<List<MediaItem>> call({MediaType? type, int? albumId, String? tag}) =>
      _repo.getMedia(type: type, albumId: albumId, tag: tag);

  Future<List<String>> tags() => _repo.getAllTags();
}

class EditPhoto {
  const EditPhoto(this._repo);
  final MediaRepository _repo;

  Future<MediaItem> call(MediaItem item, EditParams params, {required bool asCopy}) =>
      _repo.editPhoto(item, params, asCopy: asCopy);
}

class UpdateMediaMetadata {
  const UpdateMediaMetadata(this._repo);
  final MediaRepository _repo;

  Future<void> call(MediaItem item) => _repo.updateMedia(item);

  Future<void> moveToAlbum(List<MediaItem> items, int? albumId) =>
      _repo.moveToAlbum(items.map((e) => e.id).toList(), albumId);
}

class DeleteMedia {
  const DeleteMedia(this._repo);
  final MediaRepository _repo;

  Future<void> call(List<MediaItem> items) => _repo.deleteMedia(items);
}

class ManageAlbums {
  const ManageAlbums(this._repo);
  final MediaRepository _repo;

  Future<List<Album>> getAll() => _repo.getAlbums();
  Future<Album> create(String name) => _repo.createAlbum(name);
  Future<void> rename(int id, String name) => _repo.renameAlbum(id, name);
  Future<void> delete(int id) => _repo.deleteAlbum(id);
}

class TransferMedia {
  const TransferMedia(this._repo);
  final MediaRepository _repo;

  Future<String> export(List<MediaItem> items) => _repo.exportArchive(items);
  Future<int> import(String zipPath) => _repo.importArchive(zipPath);
}

class ManageStorage {
  const ManageStorage(this._repo);
  final MediaRepository _repo;

  Future<int> usage() => _repo.storageUsageBytes();
  Future<void> rebuildThumbnails() => _repo.rebuildThumbnails();
}

/// Agrupa los casos de uso para inyectarlos con un solo Provider.
class MediaUseCases {
  MediaUseCases(MediaRepository repo)
      : capturePhoto = CapturePhoto(repo),
        saveRecording = SaveRecording(repo),
        loadGallery = LoadGallery(repo),
        editPhoto = EditPhoto(repo),
        updateMetadata = UpdateMediaMetadata(repo),
        deleteMedia = DeleteMedia(repo),
        albums = ManageAlbums(repo),
        transfer = TransferMedia(repo),
        storage = ManageStorage(repo);

  final CapturePhoto capturePhoto;
  final SaveRecording saveRecording;
  final LoadGallery loadGallery;
  final EditPhoto editPhoto;
  final UpdateMediaMetadata updateMetadata;
  final DeleteMedia deleteMedia;
  final ManageAlbums albums;
  final TransferMedia transfer;
  final ManageStorage storage;
}
