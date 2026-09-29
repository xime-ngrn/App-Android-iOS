import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/color_matrix.dart';
import '../../core/utils/image_processing.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/photo_filter.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';

/// Editor no destructivo: la vista previa se aplica en GPU y solo al guardar
/// se procesa la imagen a resolución completa (en un isolate).
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

enum _Tool { filtros, ajustes, recorte }

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  static const _aspects = <String, double?>{
    'Original': null,
    '1:1': 1,
    '4:3': 4 / 3,
    '3:4': 3 / 4,
    '16:9': 16 / 9,
  };

  _Tool _tool = _Tool.filtros;
  PhotoFilter _filter = PhotoFilter.original;
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;
  int _turns = 0;
  bool _flip = false;
  double? _aspect;
  bool _saving = false;

  List<double> get _matrix => ColorMatrix.chain([
        _filter.matrix,
        ColorMatrix.saturation(_saturation),
        ColorMatrix.contrast(_contrast),
        ColorMatrix.brightness(_brightness),
      ]);

  EditParams get _params => EditParams(
        matrix: _matrix,
        quarterTurns: _turns,
        flipHorizontal: _flip,
        cropAspect: _aspect,
      );

  void _reset() => setState(() {
        _filter = PhotoFilter.original;
        _brightness = 0;
        _contrast = 1;
        _saturation = 1;
        _turns = 0;
        _flip = false;
        _aspect = null;
      });

  Future<void> _save() async {
    final params = _params;
    if (params.isNoop) {
      showSnack(context, 'No hay cambios que guardar');
      return;
    }
    final asCopy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar cambios'),
        content: const Text('¿Guardar como una foto nueva o reemplazar la original?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Reemplazar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar copia')),
        ],
      ),
    );
    if (asCopy == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await context.read<GalleryProvider>().editPhoto(widget.item, params, asCopy: asCopy);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'No se pudo guardar: $e');
      }
    }
  }

  Widget _preview() {
    final file = File(widget.item.filePath);
    Widget image = ColorFiltered(
      colorFilter: ColorFilter.matrix(_matrix),
      child: Image.file(file, cacheWidth: 1440, fit: BoxFit.contain),
    );
    image = RotatedBox(quarterTurns: _turns, child: image);
    image = Transform.flip(flipX: _flip, child: image);
    final aspect = _aspect;
    if (aspect != null) {
      image = AspectRatio(
        aspectRatio: aspect,
        child: ClipRect(child: FittedBox(fit: BoxFit.cover, child: image)),
      );
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar foto'),
        actions: [
          IconButton(tooltip: 'Restablecer', icon: const Icon(Icons.restart_alt), onPressed: _saving ? null : _reset),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: Padding(padding: const EdgeInsets.all(16), child: _preview())),
                  if (_saving)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Procesando imagen…', style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 150, child: _toolPanel()),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_Tool>(
                        segments: const [
                          ButtonSegment(value: _Tool.filtros, label: Text('Filtros'), icon: Icon(Icons.filter_vintage_outlined)),
                          ButtonSegment(value: _Tool.ajustes, label: Text('Ajustes'), icon: Icon(Icons.tune)),
                          ButtonSegment(value: _Tool.recorte, label: Text('Recorte'), icon: Icon(Icons.crop_rotate)),
                        ],
                        selected: {_tool},
                        onSelectionChanged: (s) => setState(() => _tool = s.first),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolPanel() {
    switch (_tool) {
      case _Tool.filtros:
        final primary = Theme.of(context).colorScheme.primary;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PhotoFilter.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final f = PhotoFilter.values[i];
            final selected = f == _filter;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? primary : Colors.transparent, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(f.matrix),
                        // Mismo cacheWidth para todas → una sola decodificación en caché.
                        child: Image.file(File(widget.item.filePath), cacheWidth: 160, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(f.label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            );
          },
        );
      case _Tool.ajustes:
        return ListView(
          children: [
            _slider('Brillo', Icons.brightness_6_outlined, _brightness, -100, 100, (v) => setState(() => _brightness = v)),
            _slider('Contraste', Icons.contrast, _contrast, 0.5, 1.5, (v) => setState(() => _contrast = v)),
            _slider('Saturación', Icons.palette_outlined, _saturation, 0, 2, (v) => setState(() => _saturation = v)),
          ],
        );
      case _Tool.recorte:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Girar a la izquierda',
                  onPressed: () => setState(() => _turns = (_turns + 3) % 4),
                  icon: const Icon(Icons.rotate_left),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Girar a la derecha',
                  onPressed: () => setState(() => _turns = (_turns + 1) % 4),
                  icon: const Icon(Icons.rotate_right),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Espejo',
                  isSelected: _flip,
                  onPressed: () => setState(() => _flip = !_flip),
                  icon: const Icon(Icons.flip),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in _aspects.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: _aspect == entry.value,
                    onSelected: (_) => setState(() => _aspect = entry.value),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Widget _slider(String label, IconData icon, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        SizedBox(width: 84, child: Text(label)),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ],
    );
  }
}
