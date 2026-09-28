import '../../core/utils/color_matrix.dart';

enum PhotoFilter {
  original('Original'),
  blancoNegro('B/N'),
  sepia('Sepia'),
  vintage('Vintage'),
  calido('Cálido'),
  frio('Frío'),
  contraste('Contraste'),
  vivido('Vívido'),
  negativo('Negativo');

  const PhotoFilter(this.label);
  final String label;

  List<double> get matrix => switch (this) {
        PhotoFilter.original => ColorMatrix.identity,
        PhotoFilter.blancoNegro => const <double>[
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 1, 0, //
          ],
        PhotoFilter.sepia => const <double>[
            0.393, 0.769, 0.189, 0, 0, //
            0.349, 0.686, 0.168, 0, 0, //
            0.272, 0.534, 0.131, 0, 0, //
            0, 0, 0, 1, 0, //
          ],
        PhotoFilter.vintage => const <double>[
            0.9, 0.5, 0.1, 0, 0, //
            0.3, 0.8, 0.1, 0, 0, //
            0.2, 0.3, 0.5, 0, 0, //
            0, 0, 0, 1, 0, //
          ],
        PhotoFilter.calido => const <double>[
            1.1, 0, 0, 0, 12, //
            0, 1.0, 0, 0, 4, //
            0, 0, 0.85, 0, -10, //
            0, 0, 0, 1, 0, //
          ],
        PhotoFilter.frio => const <double>[
            0.9, 0, 0, 0, -10, //
            0, 1.0, 0, 0, 0, //
            0, 0, 1.15, 0, 15, //
            0, 0, 0, 1, 0, //
          ],
        PhotoFilter.contraste => ColorMatrix.contrast(1.45),
        PhotoFilter.vivido => ColorMatrix.saturation(1.7),
        PhotoFilter.negativo => const <double>[
            -1, 0, 0, 0, 255, //
            0, -1, 0, 0, 255, //
            0, 0, -1, 0, 255, //
            0, 0, 0, 1, 0, //
          ],
      };

  static PhotoFilter fromName(String? name) =>
      PhotoFilter.values.asNameMap()[name] ?? PhotoFilter.original;
}
