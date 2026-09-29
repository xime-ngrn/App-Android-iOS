import 'package:permission_handler/permission_handler.dart';

/// Punto único para solicitar y consultar permisos en iOS y Android.
class PermissionService {
  Future<bool> requestCamera() => _request(Permission.camera);
  Future<bool> requestMicrophone() => _request(Permission.microphone);

  Future<bool> isCameraGranted() async => (await Permission.camera.status).isGranted;

  Future<Map<String, PermissionStatus>> summary() async => {
        'Cámara': await Permission.camera.status,
        'Micrófono': await Permission.microphone.status,
        'Ubicación': await Permission.locationWhenInUse.status,
      };

  Future<bool> openSettings() => openAppSettings();

  Future<bool> _request(Permission permission) async {
    final current = await permission.status;
    if (current.isGranted || current.isLimited) return true;
    // Si ya se negó de forma permanente, el sistema no vuelve a mostrar el
    // diálogo: la UI debe mandar al usuario a Ajustes.
    if (current.isPermanentlyDenied || current.isRestricted) return false;
    final result = await permission.request();
    return result.isGranted || result.isLimited;
  }
}
