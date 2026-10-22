import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_interaction_remapper.dart';
import 'package:naiweaver/features/generation/models/nai_character.dart';

void main() {
  const remapper = NaiaInteractionRemapper();

  test('remaps surviving indices after disabling an earlier slot', () {
    final interactions = [
      NaiInteraction(
        sourceCharacterIndices: [1],
        targetCharacterIndices: [2],
        actionName: 'hugging',
        type: InteractionType.sourceTarget,
      ),
    ];
    final result = remapper.remap(interactions, [false, true, true]);
    expect(result.length, 1);
    expect(result.single.sourceCharacterIndices, [0]);
    expect(result.single.targetCharacterIndices, [1]);
  });

  test('drops interactions referencing disabled slots', () {
    final interactions = [
      NaiInteraction(
        sourceCharacterIndices: [0],
        targetCharacterIndices: [1],
        actionName: 'hugging',
        type: InteractionType.sourceTarget,
      ),
    ];
    expect(remapper.remap(interactions, [true, false]), isEmpty);
    expect(interactions.single.targetCharacterIndices, [1]);
  });
  test('remaps multiple participants after filtering', () {
    final item = NaiInteraction(
      sourceCharacterIndices: [0, 2],
      targetCharacterIndices: [3],
      actionName: 'group',
      type: InteractionType.sourceTarget,
    );
    final result = remapper.remap([item], [true, false, true, true]);
    expect(result.single.sourceCharacterIndices, [0, 1]);
    expect(result.single.targetCharacterIndices, [2]);
    expect(item.sourceCharacterIndices, [0, 2]);
  });

  test('drops an interaction when one of several sources is disabled', () {
    final item = NaiInteraction(
      sourceCharacterIndices: [0, 1],
      targetCharacterIndices: [2],
      actionName: 'group',
      type: InteractionType.sourceTarget,
    );
    expect(remapper.remap([item], [true, false, true]), isEmpty);
  });

  test('drops an interaction referencing a missing character', () {
    final item = NaiInteraction(
      sourceCharacterIndices: [0],
      targetCharacterIndices: [4],
      actionName: 'group',
      type: InteractionType.sourceTarget,
    );
    expect(remapper.remap([item], [true, true]), isEmpty);
  });

}
