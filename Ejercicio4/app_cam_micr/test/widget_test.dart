import 'package:flutter_test/flutter_test.dart';

import 'package:camara_microfono/core/utils/formatters.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('formatBytes', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });
}