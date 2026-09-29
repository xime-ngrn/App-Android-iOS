import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/transfer_actions.dart';
import 'image_editor_screen.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late MediaItem _item = widget.item;

  Future<void> _save(MediaItem updated) async {
    try {
      await context.read<GalleryProvider>().updateItem(updated);
      if (mounted) setState(() => _item = updated);
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo guardar: $e');
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<MediaItem>(
      MaterialPageRoute(builder: (_) => ImageEditorScreen(item: _item)),
    );
    if (result != null && mounted) setState(() => _item = result);
  }

  Future<void> _rename() async {
    final title = await showTextInput(context, title: 'Renombrar', initial: _item.title);
    if (title != null) await _save(_item.copyWith(title: title));
  }

  Future<void> _tags() async {
    final tags = await showTagEditor(context, _item.tags, suggestions: context.read<GalleryProvider>().tags);
    if (tags != null) await _save(_item.copyWith(tags: tags));
  }

  Future<void> _album() async {
    final choice = await showAlbumPicker(context, currentId: _item.albumId);
    if (choice == null) return;
    await _save(_item.copyWith(albumId: choice.albumId, clearAlbum: choice.albumId == null));
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Eliminar foto', message: 'Se borrará del dispositivo.');
    if (!ok || !mounted) return;
    await context.read<GalleryProvider>().delete([_item]);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final album = context.select<GalleryProvider, String?>((g) => g.albumById(_item.albumId)?.name);
    final mq = MediaQuery.of(context);
    // Decodifica al doble del ancho de pantalla: suficiente para hacer zoom
    // sin cargar la foto completa en memoria.
    final decodeWidth = (mq.size.width * mq.devicePixelRatio * 2).round();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        title: Text(_item.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Renombrar', icon: const Icon(Icons.drive_file_rename_outline), onPressed: _rename),
          IconButton(tooltip: 'Información', icon: const Icon(Icons.info_outline), onPressed: () => showMediaInfo(context, _item)),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(
            File(_item.filePath),
            key: ValueKey(_item.filePath),
            fit: BoxFit.contain,
            cacheWidth: decodeWidth,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Action(icon: Icons.tune, label: 'Editar', onTap: _edit),
                _Action(icon: Icons.sell_outlined, label: 'Etiquetas', onTap: _tags),
                _Action(icon: Icons.folder_outlined, label: album ?? 'Álbum', onTap: _album),
                Builder(
                  builder: (btnContext) => _Action(
                    icon: Icons.ios_share,
                    label: 'Compartir',
                    onTap: () => shareFiles(btnContext, [_item.filePath]),
                  ),
                ),
                _Action(icon: Icons.delete_outline, label: 'Eliminar', onTap: _delete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 2),
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
}
