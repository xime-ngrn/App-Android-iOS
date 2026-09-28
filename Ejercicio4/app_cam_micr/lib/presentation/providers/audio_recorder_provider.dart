import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../core/permissions/permission_service.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/media_usecases.dart';

enum RecorderStatus { idle, countdown, recording, paused, saving, permissionDenied }

/// Sensibilidad del micrófono:
///  - [floorDb]: nivel mínimo (dBFS) que se considera sonido en el medidor.
///  - autoGain / noiseSuppress: procesamiento del sistema al grabar.
enum MicSensitivity {
  baja('Baja', -35, autoGain: false, noiseSuppress: true,
      description: 'Solo sonidos fuertes y cercanos. Ideal para lugares ruidosos.'),
  media('Media', -50, autoGain: true, noiseSuppress: true,
      description: 'Balance para voz a distancia normal.'),
  alta('Alta', -65, autoGain: true, noiseSuppress: false,
      description: 'Capta sonidos suaves y lejanos. Puede incluir ruido de fondo.');

  const MicSensitivity(this.label, this.floorDb,
      {required this.autoGain, required this.noiseSuppress, required this.description});

  final String label;
  final double floorDb;
  final bool autoGain;
  final bool noiseSuppress;
  final String description;
}

enum AudioQuality {
  voz('Voz', 64000, 22050),
  estandar('Estándar', 128000, 44100),
  alta('Alta', 192000, 48000);

  const AudioQuality(this.label, this.bitRate, this.sampleRate);
  final String label;
  final int bitRate;
  final int sampleRate;
}

/// Global (no depende de la pestaña): la grabación continúa aunque el
/// usuario navegue a la galería.
class AudioRecorderProvider extends ChangeNotifier {
  AudioRecorderProvider(this._permissions, this._useCases);

  final PermissionService _permissions;
  final MediaUseCases _useCases;
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<MediaItem> _saved = StreamController<MediaItem>.broadcast();

  static const maxDurationOptions = <Duration?>[
    null,
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];
  static const startDelayOptions = <int>[0, 3, 5];
  static const historyLength = 48;

  RecorderStatus _status = RecorderStatus.idle;
  MicSensitivity _sensitivity = MicSensitivity.media;
  AudioQuality _quality = AudioQuality.estandar;
  Duration? _maxDuration;
  int _startDelay = 0;
  int? _countdown;
  Duration _elapsed = Duration.zero;
  double _level = 0;
  double _currentDb = -160;
  final List<double> _history = [];
  String? _error;

  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final Stopwatch _stopwatch = Stopwatch();
  bool _cancelled = false;
  bool _disposed = false;

  RecorderStatus get status => _status;
  MicSensitivity get sensitivity => _sensitivity;
  AudioQuality get quality => _quality;
  Duration? get maxDuration => _maxDuration;
  int get startDelay => _startDelay;
  int? get countdown => _countdown;
  Duration get elapsed => _elapsed;
  double get level => _level;
  double get currentDb => _currentDb;
  List<double> get history => List.unmodifiable(_history);
  String? get error => _error;
  Stream<MediaItem> get onSaved => _saved.stream;

  bool get isActive =>
      _status == RecorderStatus.countdown ||
      _status == RecorderStatus.recording ||
      _status == RecorderStatus.paused ||
      _status == RecorderStatus.saving;

  void setSensitivity(MicSensitivity value) => _ifIdle(() => _sensitivity = value);
  void setQuality(AudioQuality value) => _ifIdle(() => _quality = value);
  void setMaxDuration(Duration? value) => _ifIdle(() => _maxDuration = value);
  void setStartDelay(int value) => _ifIdle(() => _startDelay = value);

  Future<void> start() async {
    if (isActive) return;
    _error = null;
    final granted = await _permissions.requestMicrophone();
    if (!granted) {
      _status = RecorderStatus.permissionDenied;
      _notify();
      return;
    }
    _status = RecorderStatus.idle;
    _cancelled = false;

    if (_startDelay > 0) {
      _status = RecorderStatus.countdown;
      for (var s = _startDelay; s > 0; s--) {
        _countdown = s;
        _notify();
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_cancelled || _disposed) {
          _countdown = null;
          _status = RecorderStatus.idle;
          _notify();
          return;
        }
      }
      _countdown = null;
    }

    final path = _useCases.saveRecording.tempPath();
    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: _quality.bitRate,
          sampleRate: _quality.sampleRate,
          numChannels: 1,
          autoGain: _sensitivity.autoGain,
          echoCancel: _sensitivity.noiseSuppress,
          noiseSuppress: _sensitivity.noiseSuppress,
        ),
        path: path,
      );
    } catch (e) {
      _error = 'No se pudo iniciar la grabación: $e';
      _status = RecorderStatus.idle;
      _notify();
      return;
    }

    _history.clear();
    _elapsed = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _status = RecorderStatus.recording;
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_onAmplitude);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    _notify();
  }

  void _onAmplitude(Amplitude amplitude) {
    if (_status != RecorderStatus.recording) return;
    final db = amplitude.current.isFinite ? amplitude.current : -160.0;
    final floor = _sensitivity.floorDb;
    _currentDb = db;
    _level = ((db - floor) / -floor).clamp(0.0, 1.0).toDouble();
    _history.add(_level);
    if (_history.length > historyLength) _history.removeAt(0);
    _notify();
  }

  void _tick() {
    _elapsed = _stopwatch.elapsed;
    final max = _maxDuration;
    if (max != null && _elapsed >= max && _status == RecorderStatus.recording) {
      stop(); // temporizador de grabación: corte automático
      return;
    }
    _notify();
  }

  Future<void> pause() async {
    if (_status != RecorderStatus.recording) return;
    await _recorder.pause();
    _stopwatch.stop();
    _level = 0;
    _status = RecorderStatus.paused;
    _notify();
  }

  Future<void> resume() async {
    if (_status != RecorderStatus.paused) return;
    await _recorder.resume();
    _stopwatch.start();
    _status = RecorderStatus.recording;
    _notify();
  }

  Future<MediaItem?> stop() async {
    if (_status != RecorderStatus.recording && _status != RecorderStatus.paused) return null;
    _status = RecorderStatus.saving;
    _stopTimers();
    _stopwatch.stop();
    _notify();
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('El grabador no devolvió ningún archivo');
      final item = await _useCases.saveRecording(sourcePath: path, duration: _stopwatch.elapsed);
      if (!_saved.isClosed) _saved.add(item);
      return item;
    } catch (e) {
      _error = 'Error al guardar la grabación: $e';
      return null;
    } finally {
      _status = RecorderStatus.idle;
      _level = 0;
      _notify();
    }
  }

  Future<void> cancel() async {
    if (_status == RecorderStatus.countdown) {
      _cancelled = true;
      return;
    }
    if (_status != RecorderStatus.recording && _status != RecorderStatus.paused) return;
    _stopTimers();
    _stopwatch.stop();
    await _recorder.cancel(); // detiene y borra el archivo temporal
    _status = RecorderStatus.idle;
    _level = 0;
    _elapsed = Duration.zero;
    _history.clear();
    _notify();
  }

  void _ifIdle(VoidCallback change) {
    if (isActive) return;
    change();
    _notify();
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    _saved.close();
    _recorder.dispose();
    super.dispose();
  }
}
