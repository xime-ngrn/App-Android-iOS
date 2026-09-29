import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/permissions/permission_service.dart';
import '../../domain/entities/photo_filter.dart';
import '../../domain/usecases/media_usecases.dart';
import '../providers/camera_provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/permission_denied_view.dart';
import '../widgets/thumbnail_image.dart';
import 'image_viewer_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CameraProvider(ctx.read<PermissionService>(), ctx.read<MediaUseCases>())..initialize(),
      child: const _CameraView(),
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView();

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// La cámara debe liberarse al ir a segundo plano (requisito en iOS y
  /// Android: otro proceso podría necesitarla).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = context.read<CameraProvider>();
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      camera.pause();
    } else if (state == AppLifecycleState.resumed) {
      camera.resume();
    }
  }

  Future<void> _capture(CameraProvider camera) async {
    if (camera.countdown != null) {
      camera.cancelCountdown();
      return;
    }
    final gallery = context.read<GalleryProvider>();
    try {
      final item = await camera.capture();
      if (item != null) {
        gallery.load();
        if (mounted) showSnack(context, 'Foto guardada');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo tomar la foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = context.watch<CameraProvider>();

    switch (camera.status) {
      case CameraStatus.permissionDenied:
        return SafeArea(
          child: PermissionDeniedView(
            icon: Icons.no_photography_outlined,
            title: 'Sin acceso a la cámara',
            message: 'Concede el permiso de cámara para tomar fotografías. '
                'Si lo negaste antes, actívalo desde los ajustes del sistema.',
            onRetry: camera.initialize,
          ),
        );
      case CameraStatus.noCamera:
        return const Center(child: Text('Este dispositivo no tiene cámara disponible.'));
      case CameraStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text('Error de cámara: ${camera.errorMessage ?? ''}', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: camera.initialize, child: const Text('Reintentar')),
            ]),
          ),
        );
      case CameraStatus.initializing:
      case CameraStatus.ready:
      case CameraStatus.paused:
        break;
    }

    final controller = camera.controller;
    final ready = controller != null && controller.value.isInitialized;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(camera: camera),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: ready
                        ? ColorFiltered(
                            // Vista previa del filtro en tiempo real.
                            colorFilter: ColorFilter.matrix(camera.filter.matrix),
                            child: CameraPreview(controller),
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
                  if (camera.countdown != null)
                    Center(
                      child: Text(
                        '${camera.countdown}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.w300,
                          shadows: [Shadow(blurRadius: 16)],
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: camera.showShutter ? 0.85 : 0,
                      duration: const Duration(milliseconds: 90),
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ),
                  if (camera.filter != PhotoFilter.original)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Chip(
                          avatar: const Icon(Icons.filter_vintage, size: 18),
                          label: Text(camera.filter.label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (ready && camera.maxZoom > camera.minZoom)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                  Expanded(
                    child: Slider(
                      value: camera.zoom,
                      min: camera.minZoom,
                      max: camera.maxZoom,
                      onChanged: camera.setZoom,
                    ),
                  ),
                  Text('${camera.zoom.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white)),
                ]),
              ),
            _FilterStrip(camera: camera),
            _BottomControls(camera: camera, onCapture: () => _capture(camera)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.camera});
  final CameraProvider camera;

  (IconData, String) get _flash => switch (camera.flashMode) {
        FlashMode.off => (Icons.flash_off, 'Flash apagado'),
        FlashMode.auto => (Icons.flash_auto, 'Flash automático'),
        FlashMode.always => (Icons.flash_on, 'Flash siempre'),
        FlashMode.torch => (Icons.flashlight_on, 'Linterna'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip) = _flash;
    final busy = camera.capturing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: camera.flashSupported ? tooltip : 'Flash no disponible',
            color: Colors.white,
            onPressed: camera.flashSupported && !busy ? camera.cycleFlash : null,
            icon: Icon(camera.flashSupported ? icon : Icons.flash_off),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: busy ? null : camera.cycleTimer,
            icon: const Icon(Icons.timer_outlined),
            label: Text(camera.timerSeconds == 0 ? 'Sin temporizador' : '${camera.timerSeconds} s'),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            color: Colors.white,
            onPressed: camera.canSwitchCamera && !busy ? camera.switchCamera : null,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.camera});
  final CameraProvider camera;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: PhotoFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final filter = PhotoFilter.values[i];
          final selected = filter == camera.filter;
          return GestureDetector(
            onTap: () => camera.setFilter(filter),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? primary : Colors.white24, width: selected ? 3 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(filter.matrix),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.pink, Colors.lightBlue, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(filter.label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.camera, required this.onCapture});
  final CameraProvider camera;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = camera.lastCaptured;
    final counting = camera.countdown != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: last == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ImageViewerScreen(item: last)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ThumbnailImage(key: ValueKey(last.id), item: last),
                    ),
                  ),
          ),
          GestureDetector(
            onTap: (camera.capturing && !counting) || camera.controller == null ? null : onCapture,
            child: Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: counting ? Colors.redAccent : scheme.primary,
                ),
                child: Center(
                  child: camera.capturing && !counting
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : Icon(counting ? Icons.close : Icons.photo_camera, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}
