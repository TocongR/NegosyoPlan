import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../i18n/tr.dart';
import '../services/generated_docs.dart';
import '../services/requirement_store.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import '../widgets/status_card.dart';

/// S22c · Upload your requirements — the one place where files are added.
///
/// Comes last: after the owner has checked every answer and made the
/// documents, just before submitting to OLEDIPO. Three requirements, all PDF:
/// * Business permit — one file.
/// * Certificate of Residency and Business Operation (Annex C), signed by the
///   barangay captain — one file.
/// * Training certificates — one or more.
///
/// Files are kept on this phone (SQLite list + copies in the app's folder).
/// On Submit they are sent online through [AppState.backend] (lib/cloud/),
/// together with Annex A, Annex D and the financial statements, which the
/// app makes from the answers (see [GeneratedDoc]).
///
/// When OLEDIPO returns the application for completion, the files can be
/// replaced, removed or added again, and the application submitted again.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _busy = false;

  /// Lets the owner pick one PDF. Returns its bytes and name, or null.
 Future<(Uint8List, String)?> _pickPdf() async {
     const pdfs = XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']);
     final file = await openFile(acceptedTypeGroups: [pdfs]);
     if (file == null) return null;
     return (await file.readAsBytes(), file.name);
   }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on NotAPdf catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Could not save the file. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addSingle(AppState app, String kind, String title) => _run(() async {
        final picked = await _pickPdf();
        if (picked == null) return;
        await app.addRequirement(kind: kind, title: title, bytes: picked.$1, fileName: picked.$2);
      });

  Future<void> _addTraining(AppState app) async {
    String name = '', provider = '', date = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Add a training certificate')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: spaced([
            FieldBlock(label: 'Name of the training', child: AppTextField(initial: '', hint: 'Example: Simple Bookkeeping', onChanged: (v) => name = v)),
            FieldBlock(label: 'Who gave it?', child: AppTextField(initial: '', hint: 'Example: DTI Negosyo Center', onChanged: (v) => provider = v)),
            FieldBlock(label: 'When?', child: AppTextField(initial: '', hint: 'Example: Mar 2025', onChanged: (v) => date = v)),
          ], 14)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Choose PDF'))),
        ],
      ),
    );
    if (ok != true) return;
    if (name.trim().isEmpty) {
      if (mounted) toast(context, 'Please type the name of the training.');
      return;
    }
    await _run(() async {
      final picked = await _pickPdf();
      if (picked == null) return;
      await app.addRequirement(kind: 'training', title: name.trim(), provider: provider.trim(), date: date.trim(), bytes: picked.$1, fileName: picked.$2);
    });
  }

  /// TESTING ONLY: adds small sample PDFs so the screen can be tried without real files.
  Future<void> _addTestPdfs(AppState app) => _run(() async {
        Future<Uint8List> pdf(String text) async {
          final d = pw.Document()..addPage(pw.Page(build: (_) => pw.Center(child: pw.Text(text))));
          return d.save();
        }

        await app.addRequirement(kind: 'permit', title: 'Business permit', bytes: await pdf('TEST · Business permit'), fileName: 'business-permit.pdf');
        await app.addRequirement(kind: 'annexC', title: 'Annex C', bytes: await pdf('TEST · Annex C signed'), fileName: 'annex-c-signed.pdf');
        await app.addRequirement(
            kind: 'training', title: 'Food Safety and Handling', provider: 'DTI Negosyo Center', date: 'Mar 2025', bytes: await pdf('TEST · Training certificate'), fileName: 'food-safety.pdf');
      });

  void _view(ReqFile f) => _viewPdf(f.fileName, (_) => File(f.path).readAsBytes());

  void _viewPdf(String title, Future<Uint8List> Function(dynamic) build) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 17)), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
          body: PdfPreview(
            build: build,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: false,
          ),
        ),
      ));

  Future<void> _remove(AppState app, ReqFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Remove this file?')),
        content: Text(f.fileName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Remove'))),
        ],
      ),
    );
    if (ok == true) await _run(() => app.removeRequirement(f.id));
  }

  Widget _fileRow(AppState app, ReqFile f, {String? title, String? sub}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(color: AppColors.tint2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.tintBorder)),
        child: Row(children: [
          const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title ?? f.fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(sub ?? '${f.sizeText} · ${tr(f.status == 'sent' ? 'Submitted' : 'Saved on this phone')}',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ]),
          ),
          IconButton(tooltip: trn('View'), onPressed: () => _view(f), icon: const Icon(Icons.visibility_outlined)),
          if (app.canEditRequirements) IconButton(tooltip: trn('Remove'), onPressed: _busy ? null : () => _remove(app, f), icon: const Icon(Icons.delete_outline)),
        ]),
      );

  Widget _section({required int n, required String title, required String rule, String? note, required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: AppColors.tint, child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))),
            const SizedBox(width: 10),
            Expanded(child: Text(tr(title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.only(left: 38), child: Text(tr(rule), style: const TextStyle(fontSize: 14, color: AppColors.muted))),
          if (note != null) ...[const SizedBox(height: 8), Text(tr(note), style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.text2))],
          const SizedBox(height: 12),
          ...spaced(children, 8),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final permit = app.reqFile('permit');
    final annexC = app.reqFile('annexC');
    final trainings = app.trainingFiles;
    // Locked after submitting, unless OLEDIPO returned it for completion.
    final done = !app.canEditRequirements;
    final again = app.returnedForCompletion;
    final missing = [
      if (permit == null) 'Business permit',
      if (annexC == null) 'Certificate of Residency and Business Operation',
      if (trainings.isEmpty) 'Training certificate',
    ];

    Widget addButton(String label, VoidCallback onTap) => OutlinedButton.icon(
          onPressed: _busy || done ? null : onTap,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(tr(label)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        );

    return AppPage(
      title: 'Upload your requirements',
      gap: 16,
      footer: Footer(vertical: true, [
        if (done)
          BigButton('See next steps', onPressed: () => Navigator.pushNamed(context, '/tracker'))
        else
          BigButton(again ? 'Submit again to OLEDIPO' : 'Submit to OLEDIPO', icon: Icons.send_outlined, onPressed: _busy || missing.isNotEmpty ? null : () => _submit(app)),
      ]),
      children: [
        if (again) ...[
          const ApplicationStatusCard(),
          NoteBox('You can now replace, remove or add files. If OLEDIPO asked you to fix an answer, fix it first, then come back here and submit again.',
              kind: NoteKind.warn),
        ] else
          Text(tr('Last step. Add each paper as a PDF. You can scan it with your phone’s camera or a scanner app and save it as PDF.'), style: AppText.lead),
        if (_busy) const LinearProgressIndicator(),
        _section(
          n: 1,
          title: 'Business permit',
          rule: 'One PDF file',
          children: [
            if (permit != null) _fileRow(app, permit),
            addButton(permit == null ? 'Choose PDF' : 'Replace PDF', () => _addSingle(app, 'permit', 'Business permit')),
          ],
        ),
        _section(
          n: 2,
          title: 'Certificate of Residency and Business Operation (Annex C)',
          rule: 'One PDF file, signed by your barangay captain',
          note: 'Print the Annex C we filled in for you, have your barangay captain sign it, then scan it as PDF.',
          children: [
            Align(alignment: Alignment.centerLeft, child: LinkButton('See the form we filled in', onPressed: () => Navigator.pushNamed(context, '/form', arguments: 'annexC'))),
            if (annexC != null) _fileRow(app, annexC),
            addButton(annexC == null ? 'Choose PDF' : 'Replace PDF', () => _addSingle(app, 'annexC', 'Certificate of Residency and Business Operation')),
          ],
        ),
        _section(
          n: 3,
          title: 'Training certificates',
          rule: 'One PDF for each certificate. Add as many as you have.',
          children: [
            for (final t in trainings)
              _fileRow(app, t, title: t.title, sub: [t.provider, t.date, t.sizeText].where((x) => x.isNotEmpty).join(' · ')),
            addButton(trainings.isEmpty ? 'Add a training certificate' : 'Add another certificate', () => _addTraining(app)),
          ],
        ),
        _section(
          n: 4,
          title: 'Forms we made for you',
          rule: 'Sent with your files. Nothing to upload.',
          note: 'These are made from your answers each time you submit, so OLEDIPO always gets the latest version.',
          children: [
            for (final g in GeneratedDoc.all)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                decoration: BoxDecoration(color: AppColors.tint2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.tintBorder)),
                child: Row(children: [
                  const Icon(Icons.description_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr(g.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: trn('View'), onPressed: () => _viewPdf(g.fileName, (_) => g.build(app)), icon: const Icon(Icons.visibility_outlined)),
                ]),
              ),
          ],
        ),
        if (!done && missing.isNotEmpty) NoteBox('Still needed: ${missing.join(', ')}.', kind: NoteKind.warn),
        if (!again) const ApplicationStatusCard(),
        NoteBox(app.backend == null
            ? 'For now your files are kept only on this phone. Sending them to OLEDIPO will be added later.'
            : 'When you submit, your answers and PDFs are sent to OLEDIPO. You need internet for this step.'),
        if (kTestAnswers && !done)
          TextButton.icon(
            onPressed: _busy ? null : () => _addTestPdfs(app),
            icon: const Icon(Icons.science_outlined),
            label: Text(tr('Add test PDFs (testing only)')),
          ),
      ],
    );
  }

  Future<void> _submit(AppState app) async {
    final again = app.returnedForCompletion;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(again ? 'Submit again to OLEDIPO?' : 'Submit to OLEDIPO?')),
        content: Text(tr(again
            ? 'Your changes will be sent to OLEDIPO to be checked again.'
            : 'Your documents and requirements will be submitted for checking. You cannot change the files after this.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Submit'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await app.submitApplication();
      if (mounted) Navigator.pushNamed(context, '/tracker');
    } catch (e) {
      debugPrint('SUBMIT FAILED: $e');
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr('Could not send. Check your internet connection and try again.')),
            // The technical reason, so the team can see what went wrong during the demo.
            content: SingleChildScrollView(child: SelectableText('$e', style: const TextStyle(fontSize: 13, color: AppColors.muted))),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('OK')))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}