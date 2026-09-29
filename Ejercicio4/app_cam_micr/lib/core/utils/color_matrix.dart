/// Matrices de color 4x5 (mismo formato que `ColorFilter.matrix`).
///
/// La MISMA matriz se usa para la vista previa en tiempo real (GPU, con
/// `ColorFiltered`) y para procesar la foto final (CPU, en un isolate),
/// así lo que el usuario ve es exactamente lo que se guarda.
class ColorMatrix {
  ColorMatrix._();

  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static bool isIdentity(List<double> m) {
    for (var i = 0; i < 20; i++) {
      if ((m[i] - identity[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// Devuelve la matriz equivalente a aplicar primero [b] y después [a].
  static List<double> multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[i * 5 + k] * b[k * 5 + j];
        }
        if (j == 4) sum += a[i * 5 + 4];
        out[i * 5 + j] = sum;
      }
    }
    return out;
  }

  /// Compone varias matrices en el orden en que se listan.
  static List<double> chain(List<List<double>> matrices) {
    var result = identity;
    for (final m in matrices) {
      result = multiply(m, result);
    }
    return result;
  }

  /// [offset] en rango aproximado -100..100 (escala 0..255).
  static List<double> brightness(double offset) => <double>[
        1, 0, 0, 0, offset, //
        0, 1, 0, 0, offset, //
        0, 0, 1, 0, offset, //
        0, 0, 0, 1, 0, //
      ];

  /// [c] = 1 no cambia nada; >1 aumenta contraste.
  static List<double> contrast(double c) {
    final t = 128 * (1 - c);
    return <double>[
      c, 0, 0, 0, t, //
      0, c, 0, 0, t, //
      0, 0, c, 0, t, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// [s] = 0 escala de grises, 1 sin cambio, >1 más saturado.
  static List<double> saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final i = 1 - s;
    return <double>[
      lr * i + s, lg * i, lb * i, 0, 0, //
      lr * i, lg * i + s, lb * i, 0, 0, //
      lr * i, lg * i, lb * i + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }
}
