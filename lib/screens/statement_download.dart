import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../i18n/tr.dart';
import '../services/pdf_service.dart';
import '../services/statements_xlsx.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Download the financial statements: the owner picks PDF or Excel.
/// Both files have the three statements, every year side by side, in the
/// layout of the OLEDIPO sample, in English.
Future<void> showStatementDownload(BuildContext context, AppState app) async {
  Widget option(BuildContext c, IconData icon, String title, String sub, Future<void> Function() go) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            Navigator.pop(c);
            try {
              await go();
            } catch (_) {
              if (context.mounted) toast(context, 'Could not make the file. Please try again.');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              IconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(tr(sub), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.download_outlined, color: AppColors.primary),
            ]),
          ),
        ),
      );

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Download your financial statements'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(tr('Income statement, cash flow and balance sheet, all years. Printed in English.'),
              style: const TextStyle(fontSize: 15, color: AppColors.text2)),
          const SizedBox(height: 16),
          option(c, Icons.picture_as_pdf_outlined, 'PDF file', 'Ready to print or send.', () async {
            final bytes = await PdfService.buildAllStatements(app);
            await Printing.sharePdf(bytes: bytes, filename: 'Financial-Statements.pdf');
          }),
          const SizedBox(height: 10),
          option(c, Icons.grid_on_outlined, 'Excel file', 'Opens in Excel or Google Sheets. The totals have formulas.', () => StatementsXlsx.share(app)),
        ]),
      ),
    ),
  );
}
