import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:negosyoplan/logic/checks.dart';
import 'package:negosyoplan/logic/format.dart';
import 'package:negosyoplan/logic/statements.dart';
import 'package:negosyoplan/models/app_data.dart';
import 'package:negosyoplan/services/requirement_store.dart';
import 'package:negosyoplan/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppState fresh() {
  final s = AppState()..now = () => DateTime(2026, 10, 15);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('account', () {
    test('PIN log-in works on the phone, any mobile format', () {
      final s = fresh();
      s.createAccount(name: 'Maria L. Santos', mobile: '0917 123 4567', pin: '2468');
      s.logout();
      expect(s.login('09171234567', '1111'), isFalse);
      expect(s.login('+63 917-123-4567', '2468'), isTrue);
    });

    test('name from the account fills Step 1', () {
      final s = fresh();
      s.createAccount(name: 'Maria L. Santos', mobile: '09171234567', pin: '2468');
      expect(s.val('fn'), 'Maria');
      expect(s.val('ln'), 'Santos');
    });
  });

  group('statements by year', () {
    test('years run from the business start to last year', () {
      final s = fresh();
      s.setVal('os', '2019-06');
      expect(s.statementYears, [2019, 2020, 2021, 2022, 2023, 2024, 2025]);
      expect(s.yearSpan(2019), 'June to December · first year');
      expect(s.yearSpan(2020), 'January to December');
    });

    test('owner can add the next year and remove only that one', () {
      final s = fresh();
      s.setVal('os', '2024-01');
      s.addYear();
      expect(s.statementYears, [2024, 2025, 2026]);
      expect(s.canRemoveYear(2026), isTrue);
      expect(s.canRemoveYear(2025), isFalse);
      s.removeYear(2026);
      expect(s.statementYears, [2024, 2025]);
    });

    test('typed lines stay as typed and the totals are added up', () {
      final s = fresh();
      s.setVal('os', '2025-01');
      s.setLine(2025, StatementType.income, 'sales', '820,000');
      s.setLine(2025, StatementType.income, 'bi', '20000');
      s.setLine(2025, StatementType.income, 'pu', '400000');
      s.setLine(2025, StatementType.income, 'ei', '15000');
      final v = s.statementValues(2025, StatementType.income);
      expect(v['sales'], '820,000');
      expect(v['tga'], '420000');
      expect(v['tcs'], '405000');
      expect(v['gi'], '415000');
      // No expenses typed yet: their total stays blank, net income uses 0 for them.
      expect(v['toe'], isNull);
      expect(v['ni'], '415000');
      expect(s.progress(2025, StatementType.income), Progress.partial);
      expect(s.progress(2025, StatementType.cashFlow), Progress.empty);
    });

    test('balance sheet totals include the assets list', () {
      final s = fresh()..data = AppData.sample();
      final v = s.statementValues(2025, StatementType.balance);
      expect(v['tnca'], '105000');
      expect(v['inv'], '15000'); // Ending inventory
      expect(v['tlc'], v['ta']); // Drawings balance it, as in the OLEDIPO template
    });

    test('later years carry Cash beginning and Capital, beginning from the year before', () {
      final s = fresh()..data = AppData.sample();
      final cf25 = s.statementValues(2025, StatementType.cashFlow);
      expect(cf25['cb'], s.statementValues(2024, StatementType.cashFlow)['ce']);
      expect(cf25['io'], s.statementValues(2025, StatementType.income)['ni']);
      expect(s.statementValues(2025, StatementType.balance)['capb'], s.statementValues(2024, StatementType.balance)['tcap']);
      expect(s.isCalculated(2025, 'cb'), isTrue);
      expect(s.isCalculated(2019, 'cb'), isFalse);
    });

    test('a total cannot be typed over', () {
      final s = fresh();
      s.setVal('os', '2025-01');
      s.setLine(2025, StatementType.cashFlow, 'cb', '1000');
      s.setLine(2025, StatementType.cashFlow, 'ce', '999999');
      expect(s.statementValues(2025, StatementType.cashFlow)['ce'], '1000');
    });

    test('a statement is complete only when every line is typed', () {
      final s = fresh();
      s.setVal('os', '2025-01');
      for (final l in cashFlowLines.where((l) => l.isInput)) {
        s.setLine(2025, StatementType.cashFlow, l.key, '1');
      }
      expect(s.progress(2025, StatementType.cashFlow), Progress.complete);
      s.setLine(2025, StatementType.cashFlow, 'cd', '');
      expect(s.progress(2025, StatementType.cashFlow), Progress.partial);
      expect(s.blankLines(2025, StatementType.cashFlow), 1);
    });
  });

  group('sample data', () {
    test('sample years are complete except the ones left empty on purpose', () {
      final s = fresh()..data = AppData.sample();
      expect(s.yearComplete(2025), isTrue);
      expect(s.progress(2019, StatementType.cashFlow), Progress.empty);
      expect(s.progress(2022, StatementType.cashFlow), Progress.empty);
      expect(s.yearComplete(2023), isTrue);
    });

    test('complete test statements give no drawings warning', () {
      final s = fresh()..data = AppData.testFill();
      expect(warnings(s).where((w) => w.id.startsWith('bs')), isEmpty);
    });

    test('JSON round trip keeps every answer', () {
      final d = AppData.sample();
      final back = AppData.fromJson(d.toJson());
      expect(back.v['bn'], 'Lola Nena’s Piaya');
      expect(back.years[2025]!.inc['sales'], '820000');
      expect(back.lists['workers']!.length, 2);
      expect(back.g['tm'], ['Sari-sari stores', 'Pasalubong shops']);
    });
  });

  group('checks', () {
    test('missing items point to the right step', () {
      final s = fresh()..data = AppData.sample();
      final labels = missingItems(s).map((m) => m.label).toList();
      expect(labels, contains('2019 cash flow statement'));
      // Requirement PDFs are not asked in the interview; they are uploaded at the end.
      expect(labels, isNot(contains('Business permit')));
      expect(labels, contains('House number and street'));
    });

    test('drawings below zero are flagged, not fixed', () {
      final s = fresh();
      s.setVal('os', '2025-01');
      s.setLine(2025, StatementType.balance, 'cash', '100000');
      s.setLine(2025, StatementType.balance, 'capb', '1000');
      expect(s.statementValues(2025, StatementType.balance)['dr'], '-99000');
      expect(warnings(s).where((w) => w.id == 'bs2025'), hasLength(1));
      expect(s.statementValues(2025, StatementType.balance)['cash'], '100000');
    });

    test('kept warnings stay hidden', () {
      final s = fresh()..data = AppData.sample();
      s.change((d) => d.keptWarnings.add('review'));
      expect(warnings(s).map((w) => w.id), isNot(contains('review')));
    });

    test('workers rule for Annex C counts 2+ years in Iloilo', () {
      final s = fresh()..data = AppData.sample();
      expect(qualifiedWorkers(s), 2);
    });

    test('list totals add the owner’s own rows', () {
      final s = fresh()..data = AppData.sample();
      expect(listTotal(s.rows('raw_prod'), qtyTimesPrice), 3000);
      expect(listTotal(s.rows('ovh_prod'), costOf), 700);
    });
  });

  group('format', () {
    test('peso', () {
      expect(peso(1234567), '₱1,234,567');
      expect(peso(null), '—');
      expect(peso(500, parens: true), '(₱500)');
    });

    test('blank stays blank', () {
      expect(amt(''), isNull);
      expect(amt('₱ 1,200'), 1200);
    });
  });

  group('business kind', () {
    test('Step 4 route follows the kind of business', () {
      final s = fresh();
      expect(s.costRoute, '/costs/prod');
      s.pick('bt', 'I buy and resell');
      expect(s.costRoute, '/costs/resell');
      s.pick('bt', 'I offer a service');
      expect(s.costRoute, '/costs/service');
    });
  });

  group('test answers', () {
    test('every question is answered and every year is complete', () {
      final s = fresh()..data = AppData.testFill();
      expect(missingItems(s), isEmpty);
      for (final y in s.statementYears) {
        expect(s.yearComplete(y), isTrue, reason: '$y');
      }
    });
  });

  group('requirement PDFs', () {
    Uint8List pdf() => Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    test('permit and Annex C keep one file; trainings can be many', () async {
      final s = fresh()..reqStore = MemoryRequirementStore();
      await s.addRequirement(kind: 'permit', title: 'Business permit', bytes: pdf(), fileName: 'a.pdf');
      await s.addRequirement(kind: 'permit', title: 'Business permit', bytes: pdf(), fileName: 'b.pdf');
      expect(s.reqFiles.where((f) => f.kind == 'permit').single.fileName, 'b.pdf');
      await s.addRequirement(kind: 'training', title: 'One', bytes: pdf(), fileName: '1.pdf');
      await s.addRequirement(kind: 'training', title: 'Two', bytes: pdf(), fileName: '2.pdf');
      expect(s.trainingFiles, hasLength(2));
      expect(s.requirementsComplete, isFalse);
      await s.addRequirement(kind: 'annexC', title: 'Annex C', bytes: pdf(), fileName: 'c.pdf');
      expect(s.requirementsComplete, isTrue);
    });

    test('only PDF files are accepted', () async {
      final s = fresh()..reqStore = MemoryRequirementStore();
      expect(
        () => s.addRequirement(kind: 'permit', title: 'x', bytes: Uint8List.fromList([1, 2, 3, 4, 5]), fileName: 'photo.jpg'),
        throwsA(isA<NotAPdf>()),
      );
    });

    test('submitting marks every file as sent', () async {
      final s = fresh()..reqStore = MemoryRequirementStore();
      await s.addRequirement(kind: 'permit', title: 'Business permit', bytes: pdf(), fileName: 'a.pdf');
      await s.submitApplication();
      expect(s.reqStatus('permit'), 'sent');
      expect(s.submitted, isTrue);
    });
  });
}
