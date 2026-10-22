import '../../features/generation/models/nai_character.dart';

/// Remaps zero-based interaction indices after conditional character filtering.
/// An interaction involving a disabled character is omitted for this generation.
class NaiaInteractionRemapper {
  const NaiaInteractionRemapper();

  List<NaiInteraction> remap(List<NaiInteraction> interactions, List<bool> enabled) {
    final indices = <int, int>{};
    var next = 0;
    for (var i = 0; i < enabled.length; i++) {
      if (enabled[i]) indices[i] = next++;
    }

    final result = <NaiInteraction>[];
    for (final interaction in interactions) {
      final sources = interaction.sourceCharacterIndices;
      final targets = interaction.targetCharacterIndices;
      if (sources.isEmpty || sources.any((i) => !indices.containsKey(i)) ||
          targets.any((i) => !indices.containsKey(i))) {
        continue;
      }
      result.add(interaction.copyWith(
        sourceCharacterIndices: sources.map((i) => indices[i]!).toList(),
        targetCharacterIndices: targets.map((i) => indices[i]!).toList(),
      ));
    }
    return result;
  }
}
