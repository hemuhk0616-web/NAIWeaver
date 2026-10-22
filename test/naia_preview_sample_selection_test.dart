import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_preview_sample_selection.dart';

void main() {
  test('maps three visible choices to the latest backing samples', () {
    expect(naiaPreviewSampleOffset(index: 0, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 10), 7);
    expect(naiaPreviewSampleOffset(index: 2, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 10), 9);
  });
  test('supports dialogs with fewer than three samples', () {
    expect(naiaPreviewSampleOffset(index: 1, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 2), 1);
    expect(naiaPreviewSampleOffset(index: 2, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 2), isNull);
  });
  test('rejects a selection after settings change', () {
    expect(naiaPreviewSampleOffset(index: 0, requestedSignature: 'old', currentSignature: 'new', samplesSignature: 'old', sampleCount: 3), isNull);
  });
  test('rejects samples left over from a different settings signature', () {
    expect(naiaPreviewSampleOffset(index: 0, requestedSignature: 'new', currentSignature: 'new', samplesSignature: 'old', sampleCount: 3), isNull);
  });
  test('rejects negative indices and empty sample lists', () {
    expect(naiaPreviewSampleOffset(index: -1, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 3), isNull);
    expect(naiaPreviewSampleOffset(index: 0, requestedSignature: 'a', currentSignature: 'a', samplesSignature: 'a', sampleCount: 0), isNull);
  });
}
