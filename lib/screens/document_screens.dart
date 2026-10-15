import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/form_preview.dart';
import '../services/pdf_service.dart';
import '../services/word_forms.dart';
import '../state/app_state.dart';
import 'statement_download.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

// S20 Consent · S21 Documents · S22 Preview · S22b Official form · S23 Submission tracker

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget option(String title, String sub, bool value, ValueChanged<bool> onChanged) => CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          radius: 14,
          child: CheckboxListTile(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr(title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            subtitle: Text(tr(sub), style: const TextStyle(fontSize: 15)),
          ),
        );
    return AppPage(
      title: 'Before we make your documents',
      footer: Footer([BigButton('Make my documents', onPressed: app.data.consentSave ? () => Navigator.pushNamed(context, '/documents') : null)]),
      children: [
        option('Save them on this phone', 'Needed to make your documents.', app.data.consentSave, (v) => app.change((d) => d.consentSave = v)),
        option('Let me share them with OLEDIPO', 'Optional. Nothing is sent until you tap Share.', app.data.consentShare, (v) => app.change((d) => d.consentShare = v)),
        const NoteBox('These documents help you apply. They do not guarantee loan approval. The EMBRACE committee decides.'),
      ],
    );
  }
}

/// The official OLEDIPO form for a document, when it has one.
WordForm? officialForm(DocType t) => switch (t) {
      DocType.plan => WordForm.annexD,
      DocType.annexA => WordForm.annexA,
      DocType.annexC => WordForm.annexC,
      _ => null,
    };

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AppPage(
      title: 'Your documents',
      gap: 14,
      footer: Footer([
        BigButton('Print all', style: BtnStyle.secondary, icon: Icons.print_outlined, onPressed: () async {
          for (final t in DocType.values) {
            final form = officialForm(t);
            await Printing.layoutPdf(
              name: form?.fileName.replaceAll('.docx', '.pdf') ?? t.fileName,
              onLayout: (_) => form == null ? PdfService.build(app, t) : FormPreview.build(app, form),
            );
          }
        }),
        BigButton('Next: upload requirements', onPressed: () => Navigator.pushNamed(context, '/requirements')),
      ]),
      children: [
        Text(tr('Saved on this phone. Tap one to check it first, then print or download.'), style: AppText.lead),
        for (final t in DocType.values)
          Builder(builder: (context) {
            final blanks = PdfService.blanks(app, t);
            final form = officialForm(t);
            return Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => form == null
                    ? Navigator.pushNamed(context, '/preview', arguments: t.name)
                    : Navigator.pushNamed(context, '/form', arguments: form.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    form == null
                        ? const IconTile(Icons.description_outlined, bg: AppColors.surface2, fg: AppColors.text2)
                        : const IconTile(Icons.article_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(t.title), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.25)),
                        Text(tr(blanks == 0 ? 'Ready' : 'Ready · $blanks ${blanks == 1 ? 'blank' : 'blanks'} marked'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: blanks == 0 ? AppColors.primary : AppColors.estimateFg)),
                        if (form != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(6)),
                            child: Text(tr('Official OLEDIPO form · Word'),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ]),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// S22b · Check the official form before saving it.
///
/// Shows the form in the OLEDIPO template's own layout with the owner's
/// answers on it. The owner reads it first, then prints it or downloads the
/// Word file. Tabs switch between Annex A, C and D.
class OfficialFormScreen extends StatefulWidget {
  const OfficialFormScreen({super.key});
  @override
  State<OfficialFormScreen> createState() => _OfficialFormScreenState();
}

class _OfficialFormScreenState extends State<OfficialFormScreen> {
  WordForm? _form;
  bool _busy = false;

  static const _tab = {WordForm.annexA: 'Annex A', WordForm.annexC: 'Annex C', WordForm.annexD: 'Annex D'};
  static const _short = {WordForm.annexA: 'Application form', WordForm.annexC: 'Barangay certificate', WordForm.annexD: 'Business plan'};
  static const _note = {
    WordForm.annexA: 'Your answers are written into the OLEDIPO form. Boxes are ticked for you. Period and purpose are left for OLEDIPO.',
    WordForm.annexC: 'Print this and bring it to your barangay captain. The captain writes their name, signs, and dates it.',
    WordForm.annexD: 'Your business plan in the OLEDIPO template. The list of items to buy is left blank. A LIDEP officer checks how the loan was used later.',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_form == null) {
      final arg = ModalRoute.of(context)?.settings.arguments as String?;
      _form = WordForm.values.firstWhere((f) => f.name == arg, orElse: () => WordForm.annexA);
    }
  }

  Future<void> _download(AppState app) async {
    setState(() => _busy = true);
    try {
      await WordForms.share(app, _form!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Could not make the Word file. Please try again.'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final form = _form!;
    return Scaffold(
      backgroundColor: AppColors.surface2,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(_short[form]!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(tr('Preview · ${form.fileName}'), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ]),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            for (final f in WordForm.values) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: f == form
                      ? FilledButton(onPressed: () {}, child: Text(tr(_tab[f]!)))
                      : OutlinedButton(onPressed: () => setState(() => _form = f), child: Text(tr(_tab[f]!))),
                ),
              ),
              if (f != WordForm.values.last) const SizedBox(width: 8),
            ],
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Check your form first'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(tr('This is how your form will look. Read it before you save or print it. ${_note[form]}'),
                    style: const TextStyle(fontSize: 15, height: 1.4)),
                LinkButton('Something wrong? Edit my answers', onPressed: () => Navigator.pushNamed(context, '/check')),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: PdfPreview(
            key: ValueKey(form),
            build: (_) => FormPreview.build(app, form),
            pdfFileName: form.fileName.replaceAll('.docx', '.pdf'),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            useActions: false,
            scrollViewDecoration: const BoxDecoration(color: AppColors.surface2),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: BigButton('Print', style: BtnStyle.secondary, icon: Icons.print_outlined, onPressed: () {
                  Printing.layoutPdf(name: form.fileName.replaceAll('.docx', '.pdf'), onLayout: (_) => FormPreview.build(app, form));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BigButton(_busy ? 'Making file…' : 'Looks right · Download',
                    icon: Icons.download_outlined, onPressed: _busy ? null : () => _download(app)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final arg = ModalRoute.of(context)?.settings.arguments;
    final type = DocTypeInfo.byName(arg as String?) ?? DocType.income;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(type.title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          // Financial statements: download as PDF or Excel (same layout as the OLEDIPO sample).
          if (type.statement != null)
            TextButton.icon(
              onPressed: () => showStatementDownload(context, app),
              icon: const Icon(Icons.download_outlined),
              label: Text(tr('Download')),
            ),
        ],
      ),
      backgroundColor: AppColors.surface2,
      body: PdfPreview(
        build: (_) => PdfService.build(app, type),
        pdfFileName: type.fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
      ),
    );
  }
}

class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  static const steps = [
    ('Print your documents', 'Annex A, Annex D, Annex C and your financial statements.'),
    ('Barangay captain signs Annex C', 'Names and dates are already filled in for you.'),
    ('Upload your requirements as PDF', 'Business permit, signed Annex C and training certificates.'),
    ('Submit to OLEDIPO', 'Done in the app. Bring the printed set if OLEDIPO asks for it.'),
    ('EMBRACE committee evaluates', 'Approval is decided by the committee, never by this app.'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final at = app.data.trackerAt.clamp(0, steps.length - 1).toInt();
    return AppPage(
      title: 'Next steps to submit',
      gap: 0,
      footer: Footer([BigButton('Go to Home', onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false))]),
      children: [
        Padding(padding: EdgeInsets.only(top: 12, bottom: 20), child: Text(tr('Done outside the app. Mark each one when finished.'), style: AppText.lead)),
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < at ? AppColors.primary : (i == at ? AppColors.tint : AppColors.surface2),
                    border: i == at ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: Text(tr(i < at ? '✓' : '${i + 1}'), style: TextStyle(fontWeight: FontWeight.w700, color: i < at ? Colors.white : AppColors.text)),
                ),
                if (i < steps.length - 1) Expanded(child: Container(width: 2, color: i < at ? AppColors.primary : AppColors.border)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(steps[i].$1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(tr(steps[i].$2), style: const TextStyle(fontSize: 15, color: AppColors.text2)),
                    if (i == at && i < steps.length - 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(width: 170, child: BigButton('Mark as done', height: 44, onPressed: () => app.change((d) => d.trackerAt = at + 1))),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
