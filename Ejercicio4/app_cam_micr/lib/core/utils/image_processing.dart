import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'color_matrix.dart';

/// Parámetros de edición. Solo contiene datos inmutables para poder
/// enviarse a otro isolate.
class EditParams {
  const EditParams({
    this.matrix = ColorMatrix.identity,
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.cropAspect,
    this.quality = 92,
  });

  final List<double> matrix;
  final int quarterTurns;
  final bool flipHorizontal;
  final double? cropAspect;
  final int quality;

  bool get isNoop =>
      ColorMatrix.isIdentity(matrix) &&
      quarterTurns % 4 == 0 &&
      !flipHorizontal &&
      cropAspect == null;
}

/// Procesamiento pesado de imágenes. Todo corre en un isolate aparte para
/// no bloquear el hilo de UI (optimización de rendimiento).
class ImageProcessing {
  ImageProcessing._();

  static Future<Uint8List> applyEdits(Uint8List bytes, EditParams params) =>
      Isolate.run(() => _applyEdits(bytes, params));

  static Future<Uint8List?> thumbnail(Uint8List bytes, {int size = 320}) =>
      Isolate.run(() => _thumbnail(bytes, size));
}

// Orden = orden de la vista previa: color → rotación → espejo → recorte.
Uint8List _applyEdits(Uint8List bytes, EditParams e) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('No se pudo decodificar la imagen');
  }
  var image = img.bakeOrientation(decoded);
  if (!ColorMatrix.isIdentity(e.matrix)) _applyMatrix(image, e.matrix);
  final turns = e.quarterTurns % 4;
  if (turns != 0) image = img.copyRotate(image, angle: 90 * turns);
  if (e.flipHorizontal) image = img.flipHorizontal(image);
  final aspect = e.cropAspect;
  if (aspect != null) image = _centerCrop(image, aspect);
  return img.encodeJpg(image, quality: e.quality);
}

Uint8List? _thumbnail(Uint8List bytes, int size) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width <= oriented.height
      ? img.copyResize(oriented, width: size, interpolation: img.Interpolation.average)
      : img.copyResize(oriented, height: size, interpolation: img.Interpolation.average);
  return img.encodeJpg(resized, quality: 75);
}

void _applyMatrix(img.Image image, List<double> m) {
  for (final px in image) {
    final r = px.r.toDouble();
    final g = px.g.toDouble();
    final b = px.b.toDouble();
    final a = px.a.toDouble();
    px.r = (m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4]).clamp(0, 255);
    px.g = (m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9]).clamp(0, 255);
    px.b = (m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]).clamp(0, 255);
  }
}

img.Image _centerCrop(img.Image image, double aspect) {
  var w = image.width;
  var h = image.height;
  if (w / h > aspect) {
    w = (h * aspect).round();
  } else {
    h = (w / aspect).round();
  }
  return img.copyCrop(
    image,
    x: (image.width - w) ~/ 2,
    y: (image.height - h) ~/ 2,
    width: w,
    height: h,
  );
}
