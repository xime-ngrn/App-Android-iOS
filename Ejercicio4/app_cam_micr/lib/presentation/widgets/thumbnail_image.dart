import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/thumbnail_service.dart';
import '../../domain/entities/media_item.dart';

/// Muestra la miniatura desde el caché LRU (o disco). Si no existe, cae al
/// archivo original decodificado a tamaño reducido (cacheWidth).
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({super.key, required this.item});
  final MediaItem item;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.thumbnailPath != widget.item.thumbnailPath ||
        oldWidget.item.sizeBytes != widget.item.sizeBytes) {
      _bytes = null;
      _load();
    }
  }

  void _load() {
    final path = widget.item.thumbnailPath;
    if (path == null) return;
    final service = context.read<ThumbnailService>();
    final hit = service.peek(path);
    if (hit != null) {
      _bytes = hit;
      return;
    }
    service.load(path).then((bytes) {
      if (mounted && bytes != null) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    if (widget.item.thumbnailPath == null) {
      return Image.file(
        File(widget.item.filePath),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, __, ___) => const _Placeholder(),
      );
    }
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined)),
      );
}
