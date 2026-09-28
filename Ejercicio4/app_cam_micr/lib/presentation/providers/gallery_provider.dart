import 'package:flutter/foundation.dart';

import '../../core/utils/image_processing.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/media_usecases.dart';

class GalleryProvider extends ChangeNotifier {
  GalleryProvider(this._useCases);

  final MediaUseCases _useCases;

  List<MediaItem> _items = const [];
  List<Album> _albums = const [];
  List<String> _tags = const [];
  MediaType? _typeFilter;
  int? _albumFilter;
  String? _tagFilter;
  bool _loading = false;
  String? _error;
  final Set<String> _selected = {};

  List<MediaItem> get items => _items;
  List<Album> get albums => _albums;
  List<String> get tags => _tags;
  MediaType? get typeFilter => _typeFilter;
  int? get albumFilter => _albumFilter;
  String? get tagFilter => _tagFilter;
  bool get loading => _loading;
  String? get error => _error;

  bool get selectionMode => _selected.isNotEmpty;
  int get selectedCount => _selected.length;
  bool isSelected(String id) => _selected.contains(id);
  List<MediaItem> get selectedItems => _items.where((i) => _selected.contains(i.id)).toList();

  Album? albumById(int? id) => id == null ? null : _albums.where((a) => a.id == id).firstOrNull;

  /// Los filtros se resuelven en SQLite (con índices), no en memoria.
  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final itemsFuture = _useCases.loadGallery(type: _typeFilter, albumId: _albumFilter, tag: _tagFilter);
      final albumsFuture = _useCases.albums.getAll();
      final tagsFuture = _useCases.loadGallery.tags();
      _items = await itemsFuture;
      _albums = await albumsFuture;
      _tags = await tagsFuture;
      if (_albumFilter != null && albumById(_albumFilter) == null) _albumFilter = null;
      final ids = _items.map((e) => e.id).toSet();
      _selected.removeWhere((id) => !ids.contains(id));
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setType(MediaType? type) {
    _typeFilter = type;
    load();
  }

  void setAlbum(int? albumId) {
    _albumFilter = albumId;
    load();
  }

  void setTag(String? tag) {
    _tagFilter = tag;
    load();
  }

  void toggleSelection(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void selectAll() {
    _selected.addAll(_items.map((e) => e.id));
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<void> delete(List<MediaItem> items) async {
    await _useCases.deleteMedia(items);
    _selected.removeAll(items.map((e) => e.id));
    await load();
  }

  Future<void> moveToAlbum(List<MediaItem> items, int? albumId) async {
    await _useCases.updateMetadata.moveToAlbum(items, albumId);
    await load();
  }

  Future<MediaItem> updateItem(MediaItem item) async {
    await _useCases.updateMetadata(item);
    await load();
    return item;
  }

  Future<MediaItem> editPhoto(MediaItem item, EditParams params, {required bool asCopy}) async {
    final result = await _useCases.editPhoto(item, params, asCopy: asCopy);
    await load();
    return result;
  }

  Future<Album> createAlbum(String name) async {
    final album = await _useCases.albums.create(name);
    await load();
    return album;
  }

  Future<void> renameAlbum(int id, String name) async {
    await _useCases.albums.rename(id, name);
    await load();
  }

  Future<void> deleteAlbum(int id) async {
    await _useCases.albums.delete(id);
    if (_albumFilter == id) _albumFilter = null;
    await load();
  }

  Future<String> exportItems(List<MediaItem> items) => _useCases.transfer.export(items);

  Future<int> importArchive(String path) async {
    final count = await _useCases.transfer.import(path);
    await load();
    return count;
  }
}
