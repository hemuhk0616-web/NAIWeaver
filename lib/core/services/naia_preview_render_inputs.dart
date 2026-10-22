/// Shared prompt composition for NAIA previews and actual image requests.
/// Style prefix and suffix are passed separately to the image service.
({String prompt, String negative}) composeNaiaRenderInputs({
  required String prompt,
  required String negative,
  required bool demoMode,
  required String demoPositivePrefix,
  required String demoNegativePrefix,
  String? styleNegative,
}) {
  final positive = demoMode && demoPositivePrefix.isNotEmpty
      ? '$demoPositivePrefix, $prompt'
      : prompt;
  final negatives = [
    if (demoMode && demoNegativePrefix.isNotEmpty) demoNegativePrefix,
    if (negative.isNotEmpty) negative,
    if (styleNegative != null && styleNegative.isNotEmpty) styleNegative,
  ];
  return (prompt: positive, negative: negatives.join(', '));
}
