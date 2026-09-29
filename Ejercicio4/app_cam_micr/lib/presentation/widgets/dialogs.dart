import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/photo_filter.dart';
import '../providers/gallery_provider.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
}) {
  final controller = TextEditingController(text: initial);
  String? clean(String v) => v.trim().isEmpty ? null : v.trim();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(ctx, clean(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, clean(controller.text)), child: const Text('Aceptar')),
      ],
    ),
  );
}

Future<List<String>?> showTagEditor(
  BuildContext context,
  List<String> initial, {
  List<String> suggestions = const [],
}) {
  final tags = [...initial];
  final controller = TextEditingController();
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void add(String raw) {
          // La coma se usa como separador interno: se elimina.
          final tag = raw.replaceAll(',', ' ').trim().toLowerCase();
          if (tag.isEmpty || tags.contains(tag)) return;
          setState(() => tags.add(tag));
          controller.clear();
        }

        final pending = suggestions.where((s) => !tags.contains(s)).toList();
        return AlertDialog(
          title: const Text('Etiquetas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: add,
                  decoration: InputDecoration(
                    hintText: 'Ej. escuela, familia, viaje',
                    suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => add(controller.text)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in tags) InputChip(label: Text(t), onDeleted: () => setState(() => tags.remove(t))),
                  ],
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Usadas antes', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final s in pending) ActionChip(label: Text(s), onPressed: () => add(s))],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, tags), child: const Text('Guardar')),
          ],
        );
      },
    ),
  );
}

/// Resultado del selector de álbum (null = el usuario canceló).
class AlbumChoice {
  const AlbumChoice(this.albumId);
  final int? albumId;
}

Future<AlbumChoice?> showAlbumPicker(BuildContext context, {int? currentId}) {
  final gallery = context.read<GalleryProvider>();
  return showModalBottomSheet<AlbumChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Nuevo álbum…'),
            onTap: () async {
              final name = await showTextInput(ctx, title: 'Nuevo álbum', hint: 'Nombre');
              if (name == null) return;
              try {
                final album = await gallery.createAlbum(name);
                if (ctx.mounted) Navigator.pop(ctx, AlbumChoice(album.id));
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, '$e');
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Sin álbum'),
            selected: currentId == null,
            onTap: () => Navigator.pop(ctx, const AlbumChoice(null)),
          ),
          for (final album in gallery.albums)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(album.name),
              trailing: Text('${album.itemCount}'),
              selected: album.id == currentId,
              onTap: () => Navigator.pop(ctx, AlbumChoice(album.id)),
            ),
        ],
      ),
    ),
  );
}

Future<void> showMediaInfo(BuildContext context, MediaItem item) {
  final album = context.read<GalleryProvider>().albumById(item.albumId);
  final location = item.hasLocation
      ? '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}'
      : 'Sin ubicación';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(leading: const Icon(Icons.title), title: const Text('Título'), subtitle: Text(item.title)),
          ListTile(leading: const Icon(Icons.event), title: const Text('Fecha'), subtitle: Text(formatDate(item.createdAt))),
          ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Ubicación'), subtitle: Text(location)),
          if (item.duration != null)
            ListTile(leading: const Icon(Icons.timer_outlined), title: const Text('Duración'), subtitle: Text(formatDuration(item.duration!))),
          if (item.filter != null)
            ListTile(leading: const Icon(Icons.filter_vintage_outlined), title: const Text('Filtro'), subtitle: Text(PhotoFilter.fromName(item.filter).label)),
          ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Álbum'), subtitle: Text(album?.name ?? 'Sin álbum')),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Etiquetas'),
            subtitle: Text(item.tags.isEmpty ? 'Sin etiquetas' : item.tags.map((t) => '#$t').join('  ')),
          ),
          ListTile(leading: const Icon(Icons.sd_storage_outlined), title: const Text('Tamaño'), subtitle: Text(formatBytes(item.sizeBytes))),
        ],
      ),
    ),
  );
}
