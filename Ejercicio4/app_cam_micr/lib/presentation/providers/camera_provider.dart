import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../core/permissions/permission_service.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/photo_filter.dart';
import '../../domain/usecases/media_usecases.dart';

enum CameraStatus { initializing, permissionDenied, noCamera, ready, paused, error }

/// Estado de la cámara. Vive solo mientras la pestaña de cámara está abierta,
/// así el hardware se libera en cuanto el usuario sale (ahorro de batería).
class CameraProvider extends ChangeNotifier {
  CameraProvider(this._permissions, this._useCases);

  final PermissionService _permissions;
  final MediaUseCases _useCases;

  static const timerOptions = <int>[0, 3, 5, 10];
  static const flashCycle = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraStatus _status = CameraStatus.initializing;
  String? _errorMessage;
  FlashMode _flashMode = FlashMode.off;
  bool _flashSupported = true;
  int _timerSeconds = 0;
  PhotoFilter _filter = PhotoFilter.original;
  int? _countdown;
  bool _capturing = false;
  bool _cancelCountdown = false;
  bool _showShutter = false;
  MediaItem? _lastCaptured;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  bool _disposed = false;

  CameraController? get controller => _controller;
  CameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  FlashMode get flashMode => _flashMode;
  bool get flashSupported => _flashSupported;
  int get timerSeconds => _timerSeconds;
  PhotoFilter get filter => _filter;
  int? get countdown => _countdown;
  bool get capturing => _capturing;
  bool get showShutter => _showShutter;
  MediaItem? get lastCaptured => _lastCaptured;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom > 8 ? 8 : _maxZoom;
  double get zoom => _zoom;
  bool get canSwitchCamera => _cameras.length > 1;

  Future<void> initialize() async {
    _errorMessage = null;
    _setStatus(CameraStatus.initializing);
    final granted = await _permissions.requestCamera();
    if (!granted) {
      _setStatus(CameraStatus.permissionDenied);
      return;
    }
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      _errorMessage = e.description ?? e.code;
      _setStatus(CameraStatus.error);
      return;
    }
    if (_cameras.isEmpty) {
      _setStatus(CameraStatus.noCamera);
      return;
    }
    final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    _cameraIndex = back >= 0 ? back : 0;
    await _startController();
  }

  Future<void> _startController() async {
    final previous = _controller;
    _controller = null;
    _safeNotify();
    await previous?.dispose();

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.veryHigh, // 1080p: buen balance calidad/tiempo de procesamiento
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _minZoom;
      _controller = controller;
      await _applyFlash(_flashMode);
      _status = CameraStatus.ready;
    } on CameraException catch (e) {
      await controller.dispose();
      const deniedCodes = {'CameraAccessDenied', 'CameraAccessDeniedWithoutPrompt', 'CameraAccessRestricted'};
      if (deniedCodes.contains(e.code)) {
        _status = CameraStatus.permissionDenied;
      } else {
        _errorMessage = e.description ?? e.code;
        _status = CameraStatus.error;
      }
    }
    _safeNotify();
  }

  Future<void> _applyFlash(FlashMode mode) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.setFlashMode(mode);
      _flashMode = mode;
      _flashSupported = true;
    } catch (_) {
      // Muchas cámaras frontales no tienen flash.
      _flashMode = FlashMode.off;
      _flashSupported = false;
    }
  }

  Future<void> cycleFlash() async {
    final next = flashCycle[(flashCycle.indexOf(_flashMode) + 1) % flashCycle.length];
    await _applyFlash(next);
    _safeNotify();
  }

  void cycleTimer() {
    _timerSeconds = timerOptions[(timerOptions.indexOf(_timerSeconds) + 1) % timerOptions.length];
    _safeNotify();
  }

  void setFilter(PhotoFilter filter) {
    _filter = filter;
    _safeNotify();
  }

  Future<void> setZoom(double value) async {
    final c = _controller;
    if (c == null) return;
    _zoom = value.clamp(_minZoom, maxZoom).toDouble();
    _safeNotify();
    try {
      await c.setZoomLevel(_zoom);
    } catch (_) {}
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera || _capturing) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startController();
  }

  void cancelCountdown() => _cancelCountdown = true;

  /// Toma la foto respetando temporizador y filtro. Lanza si hay error.
  Future<MediaItem?> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing || c.value.isTakingPicture) return null;
    _capturing = true;
    _cancelCountdown = false;
    _safeNotify();
    try {
      for (var s = _timerSeconds; s > 0; s--) {
        _countdown = s;
        _safeNotify();
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_cancelCountdown || _disposed) return null;
      }
      _countdown = null;
      _safeNotify();

      final active = _controller;
      if (active == null) return null;
      final shot = await active.takePicture();
      _flashShutter();
      final item = await _useCases.capturePhoto(sourcePath: shot.path, filter: _filter);
      _lastCaptured = item;
      return item;
    } finally {
      _capturing = false;
      _countdown = null;
      _safeNotify();
    }
  }

  void _flashShutter() {
    _showShutter = true;
    _safeNotify();
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      _showShutter = false;
      _safeNotify();
    });
  }

  // ------------------------------------------------ ciclo de vida de la app

  Future<void> pause() async {
    if (_status != CameraStatus.ready) return;
    _cancelCountdown = true;
    final c = _controller;
    _controller = null;
    _status = CameraStatus.paused;
    _safeNotify();
    await c?.dispose();
  }

  Future<void> resume() async {
    if (_status == CameraStatus.paused) {
      await _startController();
    } else if (_status == CameraStatus.permissionDenied && await _permissions.isCameraGranted()) {
      // El usuario regresó de Ajustes tras conceder el permiso.
      await initialize();
    }
  }

  void _setStatus(CameraStatus status) {
    _status = status;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    super.dispose();
  }
}
