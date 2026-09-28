import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import '../providers/audio_recorder_provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/level_meter.dart';
import '../widgets/permission_denied_view.dart';
import 'audio_player_screen.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  StreamSubscription<MediaItem>? _savedSub;

  @override
  void initState() {
    super.initState();
    _savedSub = context.read<AudioRecorderProvider>().onSaved.listen(_onSaved);
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    super.dispose();
  }

  void _onSaved(MediaItem item) {
    if (!mounted) return;
    context.read<GalleryProvider>().load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Grabación guardada (${formatDuration(item.duration ?? Duration.zero)})'),
        action: SnackBarAction(
          label: 'Escuchar',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => AudioPlayerScreen(item: item)),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AudioRecorderProvider rec) => switch (rec.status) {
        RecorderStatus.idle => 'Listo para grabar',
        RecorderStatus.countdown => 'Comienza en ${rec.countdown} s…',
        RecorderStatus.recording => 'Grabando',
        RecorderStatus.paused => 'En pausa',
        RecorderStatus.saving => 'Guardando…',
        RecorderStatus.permissionDenied => 'Sin permiso de micrófono',
      };

  String _maxLabel(Duration? d) {
    if (d == null) return 'Sin límite';
    return d.inMinutes >= 1 ? '${d.inMinutes} min' : '${d.inSeconds} s';
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<AudioRecorderProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (rec.status == RecorderStatus.permissionDenied) {
      return SafeArea(
        child: PermissionDeniedView(
          icon: Icons.mic_off_outlined,
          title: 'Sin acceso al micrófono',
          message: 'Concede el permiso de micrófono para grabar audio.',
          onRetry: rec.start,
        ),
      );
    }

    final recording = rec.status == RecorderStatus.recording;
    final paused = rec.status == RecorderStatus.paused;
    final active = rec.isActive;
    final max = rec.maxDuration;
    final progress = max == null ? null : (rec.elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Grabadora')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 12, color: recording ? Colors.red : scheme.outline),
                      const SizedBox(width: 8),
                      Text(_statusLabel(rec), style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatDuration(rec.elapsed),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (max != null) Text('Máximo ${_maxLabel(max)}', style: theme.textTheme.bodySmall),
                  if (progress != null && active) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                  const SizedBox(height: 16),
                  LevelMeter(levels: rec.history),
                  const SizedBox(height: 8),
                  Text(
                    recording
                        ? (rec.level == 0
                            ? 'Silencio (por debajo de ${rec.sensitivity.floorDb.toInt()} dB)'
                            : '${rec.currentDb.toStringAsFixed(0)} dBFS')
                        : ' ',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.outlined(
                tooltip: 'Descartar',
                iconSize: 28,
                onPressed: active && rec.status != RecorderStatus.saving ? rec.cancel : null,
                icon: const Icon(Icons.close),
              ),
              SizedBox(
                width: 84,
                height: 84,
                child: FloatingActionButton.large(
                  heroTag: 'rec',
                  onPressed: rec.status == RecorderStatus.saving || rec.status == RecorderStatus.countdown
                      ? null
                      : (recording || paused ? rec.stop : rec.start),
                  backgroundColor: recording || paused ? Colors.red : scheme.primary,
                  foregroundColor: Colors.white,
                  child: rec.status == RecorderStatus.saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(recording || paused ? Icons.stop : Icons.mic, size: 40),
                ),
              ),
              IconButton.filledTonal(
                tooltip: paused ? 'Reanudar' : 'Pausar',
                iconSize: 28,
                onPressed: recording ? rec.pause : (paused ? rec.resume : null),
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              ),
            ],
          ),
          if (rec.error != null) ...[
            const SizedBox(height: 12),
            Text(rec.error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Text('Opciones de captura', style: theme.textTheme.titleMedium),
          if (active)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Se pueden cambiar cuando no estés grabando.', style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          _Section(
            title: 'Sensibilidad del micrófono',
            subtitle: rec.sensitivity.description,
            child: SegmentedButton<MicSensitivity>(
              segments: [
                for (final s in MicSensitivity.values) ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {rec.sensitivity},
              onSelectionChanged: active ? null : (s) => rec.setSensitivity(s.first),
            ),
          ),
          _Section(
            title: 'Calidad',
            subtitle: '${rec.quality.bitRate ~/ 1000} kbps · ${rec.quality.sampleRate} Hz · AAC mono',
            child: SegmentedButton<AudioQuality>(
              segments: [
                for (final q in AudioQuality.values) ButtonSegment(value: q, label: Text(q.label)),
              ],
              selected: {rec.quality},
              onSelectionChanged: active ? null : (s) => rec.setQuality(s.first),
            ),
          ),
          _Section(
            title: 'Retardo de inicio',
            child: SegmentedButton<int>(
              segments: [
                for (final d in AudioRecorderProvider.startDelayOptions)
                  ButtonSegment(value: d, label: Text(d == 0 ? 'Inmediato' : '$d s')),
              ],
              selected: {rec.startDelay},
              onSelectionChanged: active ? null : (s) => rec.setStartDelay(s.first),
            ),
          ),
          _Section(
            title: 'Temporizador de grabación (duración máxima)',
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in AudioRecorderProvider.maxDurationOptions)
                  ChoiceChip(
                    label: Text(_maxLabel(d)),
                    selected: rec.maxDuration == d,
                    onSelected: active ? null : (_) => rec.setMaxDuration(d),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: child),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
