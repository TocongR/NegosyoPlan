import 'dart:typed_data';

import '../state/app_state.dart';
import 'form_preview.dart';
import 'pdf_service.dart';
import 'word_forms.dart';

/// The papers the app fills in from the owner's answers. On Submit they are
/// made fresh and sent with the requirement PDFs, so OLEDIPO staff can read
/// and print them (Annex C is not here: the owner uploads it signed).
class GeneratedDoc {
  /// Firestore file id and kind: gen_annexA · gen_annexD · gen_statements.
  final String kind;
  final String title;
  final String fileName;
  final Future<Uint8List> Function(AppState) build;
  const GeneratedDoc(this.kind, this.title, this.fileName, this.build);

  String get id => 'gen_$kind';

  static final all = <GeneratedDoc>[
    GeneratedDoc('annexA', 'Application form (Annex A)', 'Annex-A-Application-Form.pdf', (s) => FormPreview.build(s, WordForm.annexA)),
    GeneratedDoc('annexD', 'Business plan (Annex D)', 'Annex-D-Business-Plan.pdf', (s) => FormPreview.build(s, WordForm.annexD)),
    GeneratedDoc('statements', 'Financial statements', 'Financial-Statements.pdf', PdfService.buildAllStatements),
  ];
}