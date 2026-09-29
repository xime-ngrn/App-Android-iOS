import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/transfer_actions.dart';

/// Reproductor de grabaciones con barra de progreso, saltos de 10 s y
/// control de velocidad. El reproductor vive solo mientras la pantalla
/// está abierta (se libera en dispose).
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  late MediaItem _item = widget.item;
  String? _loadError;
  double _speed = 1.0;

  /// Mientras el usuario arrastra el slider no seguimos el stream de posición.
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(_item.filePath);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(PlayerState state) async {
    if (state.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (state.playing) {
      await _player.pause();
    } else {
      // play() no termina hasta que se pausa: no se espera.
      unawaited(_player.play());
    }
  }

  Future<void> _skip(Duration delta) async {
    final total = _player.duration ?? Duration.zero;
    var target = _player.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    await _player.seek(target);
  }

  Future<void> _save(MediaItem updated) async {
    try {
      await context.read<GalleryProvider>().updateItem(updated);
      if (mounted) setState(() => _item = updated);
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo guardar: $e');
    }
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
    final ok = await confirmDialog(context, title: 'Eliminar grabación', message: 'Se borrará del dispositivo.');
    if (!ok || !mounted) return;
    await _player.stop();
    if (!mounted) return;
    await context.read<GalleryProvider>().delete([_item]);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final album = context.select<GalleryProvider, String?>((g) => g.albumById(_item.albumId)?.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Renombrar', icon: const Icon(Icons.drive_file_rename_outline), onPressed: _rename),
          IconButton(tooltip: 'Información', icon: const Icon(Icons.info_outline), onPressed: () => showMediaInfo(context, _item)),
        ],
      ),
      body: SafeArea(
        child: _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo abrir el audio.\n$_loadError', textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.graphic_eq, size: 96, color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(_item.title, style: text.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(formatDate(_item.createdAt), style: text.bodyMedium, textAlign: TextAlign.center),
                  if (_item.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final t in _item.tags) Chip(label: Text('#$t'), visualDensity: VisualDensity.compact)],
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildProgress(text),
                  const SizedBox(height: 8),
                  _buildControls(scheme),
                  const SizedBox(height: 24),
                  Text('Velocidad', style: text.labelLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Center(
                    child: SegmentedButton<double>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0.5, label: Text('0.5×')),
                        ButtonSegment(value: 1.0, label: Text('1×')),
                        ButtonSegment(value: 1.5, label: Text('1.5×')),
                        ButtonSegment(value: 2.0, label: Text('2×')),
                      ],
                      selected: {_speed},
                      onSelectionChanged: (s) {
                        setState(() => _speed = s.first);
                        _player.setSpeed(_speed);
                      },
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
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
    );
  }

  Widget _buildProgress(TextTheme text) {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? _item.duration ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            var position = posSnap.data ?? Duration.zero;
            if (position > total) position = total;
            final maxMs = total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
            final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs);
            return Column(
              children: [
                Slider(
                  value: value,
                  max: maxMs,
                  onChanged: total == Duration.zero ? null : (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    await _player.seek(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _dragValue = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(Duration(milliseconds: value.round())), style: text.bodySmall),
                      Text(formatDuration(total), style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControls(ColorScheme scheme) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final state = snap.data ?? PlayerState(false, ProcessingState.idle);
        final loading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        final showPause = state.playing && state.processingState != ProcessingState.completed;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Retroceder 10 s',
              iconSize: 36,
              icon: const Icon(Icons.replay_10),
              onPressed: () => _skip(const Duration(seconds: -10)),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 72,
              height: 72,
              child: loading
                  ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator())
                  : IconButton.filled(
                      tooltip: showPause ? 'Pausa' : 'Reproducir',
                      iconSize: 40,
                      icon: Icon(showPause ? Icons.pause : Icons.play_arrow),
                      onPressed: () => _togglePlay(state),
                    ),
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: 'Adelantar 10 s',
              iconSize: 36,
              icon: const Icon(Icons.forward_10),
              onPressed: () => _skip(const Duration(seconds: 10)),
            ),
          ],
        );
      },
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
              Icon(icon),
              const SizedBox(height: 2),
              SizedBox(
                width: 72,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ),
        ),
      );
}
