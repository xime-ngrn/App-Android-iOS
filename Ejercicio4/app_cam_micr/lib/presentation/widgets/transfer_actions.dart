import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import 'dialogs.dart';

/// Comparte archivos. [context] debe ser el del botón para que en iPad el
/// menú aparezca anclado a él (si no, iPadOS lanza una excepción).
Future<void> shareFiles(BuildContext context, List<String> paths, {String? text}) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: paths.map((p) => XFile(p)).toList(),
      text: text,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// Empaqueta los elementos en un ZIP (archivos + manifest.json con
/// metadatos) y abre la hoja de compartir del sistema.
Future<void> exportItems(BuildContext context, List<MediaItem> items) async {
  if (items.isEmpty) {
    showSnack(context, 'No hay elementos para exportar');
    return;
  }
  final gallery = context.read<GalleryProvider>();
  showSnack(context, 'Preparando ${items.length} elemento(s)…');
  try {
    final zip = await gallery.exportItems(items);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await shareFiles(context, [zip], text: 'Exportación CamMic (${items.length} elementos)');
  } catch (e) {
    if (context.mounted) showSnack(context, 'No se pudo exportar: $e');
  }
}

Future<void> importFromZip(BuildContext context) async {
  final gallery = context.read<GalleryProvider>();
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
  );
  final path = result?.files.single.path;
  if (path == null || !context.mounted) return;
  showSnack(context, 'Importando…');
  try {
    final count = await gallery.importArchive(path);
    if (context.mounted) {
      showSnack(context, count == 0 ? 'No había elementos nuevos' : 'Se importaron $count elementos');
    }
  } catch (e) {
    if (context.mounted) showSnack(context, 'Error al importar: $e');
  }
}
