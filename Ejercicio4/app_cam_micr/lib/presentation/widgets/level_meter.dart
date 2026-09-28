import 'package:flutter/material.dart';

/// Medidor de nivel tipo "forma de onda" con el historial reciente.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.levels, this.bars = 32, this.height = 88});

  final List<double> levels;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = List<double>.filled(bars, 0);
    final start = levels.length > bars ? levels.length - bars : 0;
    final visible = levels.sublist(start);
    for (var i = 0; i < visible.length; i++) {
      values[bars - visible.length + i] = visible[i];
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  height: 4 + v * (height - 4),
                  decoration: BoxDecoration(
                    color: Color.lerp(scheme.primary.withValues(alpha: 0.35), scheme.primary, v),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
