import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/thumbnail_image.dart';
import '../widgets/transfer_actions.dart';
import 'albums_screen.dart';
import 'audio_player_screen.dart';
import 'image_viewer_screen.dart';

enum _Kind { all, photo, audio }

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _open(BuildContext context, MediaItem item) async {
    final gallery = context.read<GalleryProvider>();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => item.isPhoto ? ImageViewerScreen(item: item) : AudioPlayerScreen(item: item),
    ));
    gallery.load();
  }

  PreferredSizeWidget _selectionBar(BuildContext context, GalleryProvider g) {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: g.clearSelection),
      title: Text('${g.selectedCount} seleccionados'),
      actions: [
        IconButton(tooltip: 'Seleccionar todo', icon: const Icon(Icons.select_all), onPressed: g.selectAll),
        IconButton(
          tooltip: 'Mover a álbum',
          icon: const Icon(Icons.drive_file_move_outline),
          onPressed: () async {
            final items = g.selectedItems;
            final choice = await showAlbumPicker(context);
            if (choice == null) return;
            await g.moveToAlbum(items, choice.albumId);
            g.clearSelection();
          },
        ),
        Builder(
          builder: (btnContext) => IconButton(
            tooltip: 'Exportar',
            icon: const Icon(Icons.ios_share),
            onPressed: () => exportItems(btnContext, g.selectedItems),
          ),
        ),
        IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final items = g.selectedItems;
            final ok = await confirmDialog(
              context,
              title: 'Eliminar ${items.length} elemento(s)',
              message: 'Los archivos se borrarán del dispositivo. Esta acción no se puede deshacer.',
            );
            if (ok) await g.delete(items);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GalleryProvider>();
    return PopScope(
      canPop: !g.selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) g.clearSelection();
      },
      child: Scaffold(
        appBar: g.selectionMode
            ? _selectionBar(context, g)
            : AppBar(
                title: const Text('Galería'),
                actions: [
                  IconButton(
                    tooltip: 'Álbumes',
                    icon: const Icon(Icons.folder_copy_outlined),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const AlbumsScreen())),
                  ),
                  IconButton(
                    tooltip: 'Importar ZIP',
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: () => importFromZip(context),
                  ),
                ],
              ),
        body: Column(
          children: [
            _Filters(gallery: g),
            Expanded(
              child: RefreshIndicator(
                onRefresh: g.load,
                child: _content(context, g),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, GalleryProvider g) {
    if (g.loading && g.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (g.items.isEmpty) {
      final filtered = g.typeFilter != null || g.albumFilter != null || g.tagFilter != null;
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.photo_library_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            filtered ? 'No hay contenido con estos filtros' : 'Aún no hay capturas.\nUsa la cámara o la grabadora.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: g.items.length,
      itemBuilder: (context, i) {
        final item = g.items[i];
        return _MediaTile(
          key: ValueKey('${item.id}_${item.sizeBytes}'),
          item: item,
          selected: g.isSelected(item.id),
          selectionMode: g.selectionMode,
          onTap: () => g.selectionMode ? g.toggleSelection(item.id) : _open(context, item),
          onLongPress: () => g.toggleSelection(item.id),
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.gallery});
  final GalleryProvider gallery;

  _Kind get _kind => switch (gallery.typeFilter) {
        null => _Kind.all,
        MediaType.photo => _Kind.photo,
        MediaType.audio => _Kind.audio,
      };

  @override
  Widget build(BuildContext context) {
    final g = gallery;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Kind>(
              segments: const [
                ButtonSegment(value: _Kind.all, label: Text('Todo'), icon: Icon(Icons.apps)),
                ButtonSegment(value: _Kind.photo, label: Text('Fotos'), icon: Icon(Icons.photo_outlined)),
                ButtonSegment(value: _Kind.audio, label: Text('Audios'), icon: Icon(Icons.graphic_eq)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => g.setType(switch (s.first) {
                _Kind.all => null,
                _Kind.photo => MediaType.photo,
                _Kind.audio => MediaType.audio,
              }),
            ),
          ),
        ),
        if (g.albums.isNotEmpty || g.tags.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final a in g.albums)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${a.name} · ${a.itemCount}'),
                      selected: g.albumFilter == a.id,
                      onSelected: (_) => g.setAlbum(g.albumFilter == a.id ? null : a.id),
                    ),
                  ),
                for (final t in g.tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('#$t'),
                      selected: g.tagFilter == t,
                      onSelected: (_) => g.setTag(g.tagFilter == t ? null : t),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: selected ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.isPhoto)
                ThumbnailImage(item: item)
              else
                ColoredBox(
                  color: scheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq, size: 36, color: scheme.onSecondaryContainer),
                        const SizedBox(height: 4),
                        Text(
                          formatDuration(item.duration ?? Duration.zero),
                          style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              if (item.tags.isNotEmpty || item.hasLocation)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Row(children: [
                    if (item.hasLocation) const _Badge(icon: Icons.place),
                    if (item.tags.isNotEmpty) const _Badge(icon: Icons.sell),
                  ]),
                ),
              if (selectionMode)
                ColoredBox(color: selected ? scheme.primary.withValues(alpha: 0.35) : Colors.transparent),
              if (selectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 12, color: Colors.white),
      );
}
