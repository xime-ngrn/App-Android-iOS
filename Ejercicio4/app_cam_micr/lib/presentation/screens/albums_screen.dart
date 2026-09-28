import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/album.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';

/// Lista de álbumes. Al elegir uno se aplica como filtro en la galería.
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await showTextInput(context, title: 'Nuevo álbum', hint: 'Nombre');
    if (name == null || !context.mounted) return;
    try {
      await context.read<GalleryProvider>().createAlbum(name);
    } catch (e) {
      if (context.mounted) showSnack(context, 'No se pudo crear: $e');
    }
  }

  Future<void> _rename(BuildContext context, Album album) async {
    final name = await showTextInput(context, title: 'Renombrar álbum', initial: album.name);
    if (name == null || !context.mounted) return;
    try {
      await context.read<GalleryProvider>().renameAlbum(album.id, name);
    } catch (e) {
      if (context.mounted) showSnack(context, 'No se pudo renombrar: $e');
    }
  }

  Future<void> _delete(BuildContext context, Album album) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar "${album.name}"',
      message: 'Los ${album.itemCount} elementos NO se borran: quedan "Sin álbum".',
    );
    if (!ok || !context.mounted) return;
    await context.read<GalleryProvider>().deleteAlbum(album.id);
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Álbumes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Nuevo álbum'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.photo_library_outlined, color: scheme.onSecondaryContainer),
            ),
            title: const Text('Todo el contenido'),
            selected: gallery.albumFilter == null,
            onTap: () {
              gallery.setAlbum(null);
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          if (gallery.albums.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aún no hay álbumes. Crea uno para organizar tus fotos y grabaciones.',
                  textAlign: TextAlign.center),
            ),
          for (final album in gallery.albums)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.folder_outlined, color: scheme.onPrimaryContainer),
              ),
              title: Text(album.name),
              subtitle: Text(album.itemCount == 1 ? '1 elemento' : '${album.itemCount} elementos'),
              selected: gallery.albumFilter == album.id,
              onTap: () {
                gallery.setAlbum(album.id);
                Navigator.of(context).pop();
              },
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'rename' ? _rename(context, album) : _delete(context, album),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
