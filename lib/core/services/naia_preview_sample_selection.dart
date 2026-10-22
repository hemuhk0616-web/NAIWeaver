/// Returns the backing sample index for a dialog selection, or null when stale.
/// The dialog exposes only the newest three samples.
int? naiaPreviewSampleOffset({
  required int index,
  required String requestedSignature,
  required String currentSignature,
  required String? samplesSignature,
  required int sampleCount,
}) {
  if (requestedSignature != currentSignature ||
      requestedSignature != samplesSignature) {
    return null;
  }
  final firstVisible = sampleCount > 3 ? sampleCount - 3 : 0;
  final visibleCount = sampleCount - firstVisible;
  if (index < 0 || index >= visibleCount) return null;
  return firstVisible + index;
}
