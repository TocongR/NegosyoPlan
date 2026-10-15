import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../state/app_state.dart';
import 'pdf_service.dart';
import 'word_forms.dart';

/// The on-phone preview of an official form, in the template's own layout.
///
/// Phones cannot show a Word file inside the app, so the preview is a PDF:
/// a picture of each blank page of the OLEDIPO form, with the owner's answers
/// written on the blanks and ticks on the boxes — like filling in the paper
/// form by hand. The answers are the same ones the Word file gets
/// ([WordForms.data]), so what the owner checks is what they download.
///
/// `assets/forms/forms_layout.json` says where each blank and box is. It is
/// measured from the templates by `tool/templates/geometry.py`; run it again
/// whenever a template changes.
class FormPreview {
  FormPreview._();

  static Map<String, dynamic>? _layout;

  static Future<Map<String, dynamic>> _loadLayout() async =>
      _layout ??= jsonDecode(await rootBundle.loadString('assets/forms/forms_layout.json')) as Map<String, dynamic>;

  static const _ink = PdfColor.fromInt(0xFF111111);

  /// Builds the preview PDF. It can also be printed as it is.
  static Future<Uint8List> build(AppState s, WordForm f) async {
    final layout = (await _loadLayout())[f.name] as Map<String, dynamic>;
    final (values, flags) = WordForms.data(s, f);
    final doc = pw.Document(theme: await PdfService.loadTheme(), title: f.title, author: 'NegosyoPlan');

    final pages = (layout['pages'] as List).cast<Map<String, dynamic>>();
    final fields = (layout['fields'] as Map<String, dynamic>);
    final checks = (layout['checks'] as Map<String, dynamic>);

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final bg = pw.MemoryImage((await rootBundle.load(page['image'] as String)).buffer.asUint8List());
      final items = <pw.Widget>[pw.Positioned.fill(child: pw.Image(bg, fit: pw.BoxFit.fill))];

      fields.forEach((key, boxes) {
        final v = (values[key] ?? '').trim();
        if (v.isEmpty) return;
        for (final b in (boxes as List).cast<Map<String, dynamic>>()) {
          if (b['p'] != i) continue;
          items.add(_text(v, b));
        }
      });
      for (final flag in flags) {
        final b = checks[flag] as Map<String, dynamic>?;
        if (b == null || b['p'] != i) continue;
        items.add(_tick(b));
      }

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(_d(page['w']), _d(page['h'])),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(fit: pw.StackFit.expand, children: items),
      ));
    }
    return doc.save();
  }

  static double _d(dynamic v) => (v as num).toDouble();

  /// One answer, written where the template's blank starts.
  static pw.Widget _text(String v, Map<String, dynamic> b) {
    final size = _d(b['size']) * 0.95;
    final style = pw.TextStyle(fontSize: size, color: _ink);
    if (b['multi'] == true) {
      final h = _d(b['h']);
      return pw.Positioned(
        left: _d(b['x']),
        top: _d(b['y']),
        child: pw.SizedBox(
          width: _d(b['w']),
          height: h,
          child: pw.Text(v, style: style.copyWith(lineSpacing: 1), maxLines: (h / (size * 1.25)).floor().clamp(1, 20).toInt()),
        ),
      );
    }
    // One line: shrink long answers so they stay inside the blank.
    return pw.Positioned(
      left: _d(b['x']),
      top: _d(b['y']) - 1,
      child: pw.SizedBox(
        width: _d(b['w']),
        height: size * 1.3,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(v.replaceAll('\n', ' '), style: style),
        ),
      ),
    );
  }

  /// A tick on a box (or in front of a sentence on Annex C).
  static pw.Widget _tick(Map<String, dynamic> b) {
    final w = _d(b['w']), h = _d(b['h']);
    return pw.Positioned(
      left: _d(b['x']),
      top: _d(b['y']),
      child: pw.SizedBox(
        width: w,
        height: h,
        child: pw.Center(
          child: pw.Text('✓', style: pw.TextStyle(fontSize: h * 1.05, fontWeight: pw.FontWeight.bold, color: _ink)),
        ),
      ),
    );
  }
}
