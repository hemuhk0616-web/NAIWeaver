import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_resolution_directive.dart';

void main() {
  test('extracts supported portrait resolution and removes directive', () {
    final result = NaiaResolutionDirective.extract('blue hair, resolution:832x1216, smile');
    expect(result.prompt, 'blue hair, smile');
    expect(result.width, 832);
    expect(result.height, 1216);
  });

  test('leaves invalid resolution intact', () {
    final result = NaiaResolutionDirective.extract('resolution:999x999, smile');
    expect(result.width, isNull);
    expect(result.prompt, 'resolution:999x999, smile');
  });

  test('preserves ordinary prompt with no directive', () {
    final result = NaiaResolutionDirective.extract('1.5::blue hair::, smile');
    expect(result.prompt, '1.5::blue hair::, smile');
  });
}
