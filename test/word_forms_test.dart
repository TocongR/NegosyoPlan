import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:negosyoplan/models/app_data.dart';
import 'package:negosyoplan/services/requirement_store.dart';
import 'package:negosyoplan/services/word_forms.dart';
import 'package:negosyoplan/state/app_state.dart';

AppState sample() => AppState()
  ..now = () => DateTime(2026, 10, 15)
  ..data = AppData.sample();

void main() {
  group('filler', () {
    test('values are escaped and blanks use the default', () {
      const xml = '<w:t>{{a}}</w:t><w:t>{{b|____}}</w:t>';
      expect(DocxFiller.fillXml(xml, {'a': 'Tom & Jerry <1>'}, {}), '<w:t>Tom &amp; Jerry &lt;1&gt;</w:t><w:t>____</w:t>');
    });

    test('check marks show only when the flag is on', () {
      const xml = 'x<w:r><w:t>{{#male}}</w:t></w:r><w:r>TICK</w:r><w:r><w:t>{{/male}}</w:t></w:r>y';
      expect(DocxFiller.fillXml(xml, {}, {'male'}), 'x<w:r>TICK</w:r>y');
      expect(DocxFiller.fillXml(xml, {}, {}), 'xy');
    });
  });

  group('Annex A', () {
    test('answers go to the right blanks and boxes', () async {
      final s = sample()..reqStore = MemoryRequirementStore();
      await s.addRequirement(kind: 'permit', title: 'Business permit', bytes: Uint8List.fromList('%PDF-1.4'.codeUnits), fileName: 'p.pdf');
      final (v, f) = WordForms.annexA(s);
      expect(v['last'], 'Santos');
      expect(v['dob'], '05/12/1981');
      expect(v['age'], '45');
      expect(v['contact'], '0917 123 4567');
      expect(v['years_op'], '7');
      expect(v['emp_total'], '2');
      expect(v['gross_sales'], '820,000.00');
      expect(v['loan'], '100,000.00');
      expect(f, containsAll(['d2', 'female', 'married', 'reg_mayor', 'type_mfg', 'own_single']));
      expect(f, isNot(contains('male')));
    });
  });

  group('Annex C', () {
    test('owner, barangay and crisis answer', () {
      final (v, f) = WordForms.annexC(sample());
      expect(v['brgy'], 'Tabuc Suba');
      expect(v['operating_since'], 'June 2019');
      expect(f, {'lost_sales'});
    });
  });

  group('Annex D', () {
    test('production cost uses the owner’s own rows', () {
      final (v, _) = WordForms.annexD(sample());
      expect(v['pc_materials'], '3,000.00');
      expect(v['pc_total'], '5,200.00');
      expect(v['pc_per_unit'], '104.00');
      expect(v['emp2_status'], 'On-call');
      expect(v['net_income'], '180,000.00');
    });

    test('extra rows share the last line', () {
      expect(WordForms.fit(['a', 'b', 'c'], 2), ['a', 'b; c']);
      expect(WordForms.fit(['a'], 3), ['a', '', '']);
    });
  });

  group('preview layout', () {
    test('every answer and box has a place on the form picture', () {
      final layout = jsonDecode(File('assets/forms/forms_layout.json').readAsStringSync()) as Map<String, dynamic>;
      for (final f in WordForm.values) {
        final l = layout[f.name] as Map<String, dynamic>;
        final (values, flags) = WordForms.data(sample(), f);
        expect((l['fields'] as Map).keys, containsAll(values.keys), reason: f.name);
        expect((l['checks'] as Map).keys, containsAll(flags), reason: f.name);
      }
    });
  });
}
