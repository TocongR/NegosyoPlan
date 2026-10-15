import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negosyoplan/models/app_data.dart';
import 'package:negosyoplan/services/statements_xlsx.dart';
import 'package:negosyoplan/state/app_state.dart';

void main() {
  test('Excel file has the three statements with the sample formulas', () {
    final s = AppState()
      ..now = () => DateTime(2026, 10, 15)
      ..data = AppData.testFill();
    final zip = ZipDecoder().decodeBytes(StatementsXlsx.build(s));
    final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(sheet, contains('INCOME STATEMENT'));
    expect(sheet, contains('CASH FLOW STATEMENT'));
    expect(sheet, contains('BALANCE SHEET'));
    expect(sheet, contains('For the Period Ended December 31, 2025'));
    expect(sheet, contains('<f>SUM('));
    expect(sheet, contains('<rowBreaks count="2"'));
  });

  test('column letters', () {
    expect(StatementsXlsx.col(0), 'A');
    expect(StatementsXlsx.col(25), 'Z');
    expect(StatementsXlsx.col(26), 'AA');
  });
}
