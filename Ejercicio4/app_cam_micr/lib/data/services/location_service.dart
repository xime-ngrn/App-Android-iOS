import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Obtiene la ubicación para los metadatos. Nunca lanza: si no hay permiso,
/// GPS o tiempo, simplemente devuelve null y la captura se guarda igual.
class LocationService {
  LocationService({required bool Function() isEnabled}) : _isEnabled = isEnabled;

  final bool Function() _isEnabled;

  Future<GeoPoint?> tryGetLocation() async {
    if (!_isEnabled()) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }
      // Optimización: la última posición conocida es instantánea.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final timestamp = last.timestamp as DateTime?;
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < const Duration(minutes: 5)) {
          return GeoPoint(last.latitude, last.longitude);
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
