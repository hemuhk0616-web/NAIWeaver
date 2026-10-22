import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_preview_render_inputs.dart';

void main() {
  test('keeps ordinary prompts unchanged when demo and style are off', () {
    final result = composeNaiaRenderInputs(prompt: 'main', negative: 'uc', demoMode: false, demoPositivePrefix: 'demo', demoNegativePrefix: 'demo uc');
    expect(result.prompt, 'main');
    expect(result.negative, 'uc');
  });
  test('includes demo positive and negative prefixes in order', () {
    final result = composeNaiaRenderInputs(prompt: 'main', negative: 'uc', demoMode: true, demoPositivePrefix: 'demo', demoNegativePrefix: 'demo uc');
    expect(result.prompt, 'demo, main');
    expect(result.negative, 'demo uc, uc');
  });
  test('appends style negative to the composed negative prompt', () {
    final result = composeNaiaRenderInputs(prompt: 'main', negative: 'uc', demoMode: true, demoPositivePrefix: 'demo', demoNegativePrefix: 'demo uc', styleNegative: 'style uc');
    expect(result.negative, 'demo uc, uc, style uc');
  });
  test('does not add leading commas for empty negative prompts', () {
    final result = composeNaiaRenderInputs(prompt: 'main', negative: '', demoMode: false, demoPositivePrefix: '', demoNegativePrefix: '', styleNegative: 'style uc');
    expect(result.negative, 'style uc');
  });
  test('omits empty prefixes and suffixes', () {
    final result = composeNaiaRenderInputs(prompt: 'main', negative: '', demoMode: true, demoPositivePrefix: '', demoNegativePrefix: '', styleNegative: '');
    expect(result.prompt, 'main');
    expect(result.negative, '');
  });
}
