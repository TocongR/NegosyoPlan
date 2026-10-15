import 'package:flutter_test/flutter_test.dart';
import 'package:negosyoplan/i18n/tr.dart';

void main() {
  tearDown(() => Lang.code = 'hil');

  test('screens show Hiligaynon by default', () {
    Lang.code = 'hil';
    expect(tr('Next'), 'Sunod');
    expect(tr('Sales'), 'Sales (Benta)');
    expect(tr('3 lines still blank'), '3 ka linya ang blangko pa');
    expect(tr('Cash ending of 2024'), 'Cash ending sang 2024');
    expect(tr('STEP 5 OF 9 · PART 1 OF 3 · SAVED'), 'HAKBANG 5 SA 9 · PARTE 1 SA 3 · NA-SAVE');
  });

  test('text without a translation stays as it is', () {
    Lang.code = 'hil';
    expect(tr('Lola Nena’s Piaya'), 'Lola Nena’s Piaya');
  });

  test('English and Filipino show the English text', () {
    Lang.code = 'en';
    expect(tr('Next'), 'Next');
    Lang.code = 'fil';
    expect(tr('Next'), 'Next');
  });
}
