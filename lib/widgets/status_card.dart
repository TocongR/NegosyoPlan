import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/tr.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Shows where the submitted application is, as set by OLEDIPO staff:
/// Pending for checking · Returned for completion · Accepted.
/// Nothing is shown before the owner submits.
class ApplicationStatusCard extends StatelessWidget {
  const ApplicationStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.submitted) return const SizedBox.shrink();
    // On the upload screen itself, "Fix files and submit" would open the same screen.
    final onUploadScreen = ModalRoute.of(context)?.settings.name == '/requirements';

    final (IconData icon, String title, String text, Color bg, Color fg) = switch (app.data.appStatus) {
      'Accepted' => (
          Icons.verified_outlined,
          'Accepted',
          'Your papers are complete. The EMBRACE committee will now decide on your loan.',
          AppColors.tint,
          AppColors.primary,
        ),
      'Returned for completion' => (
          Icons.assignment_return_outlined,
          'Returned for completion',
          'OLEDIPO needs something more from you. Fix it, then submit again.',
          AppColors.missingBg,
          AppColors.missingFg,
        ),
      _ => (
          Icons.hourglass_top_outlined,
          'Pending for checking',
          'OLEDIPO staff are checking your papers. We will show the result here.',
          AppColors.estimateBg,
          AppColors.estimateFg,
        ),
    };

    return Semantics(
      container: true,
      label: '${tr('Application status')}: ${tr(title)}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: fg.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Application status'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(icon, color: fg, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(tr(title), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: fg))),
          ]),
          const SizedBox(height: 8),
          Text(tr(text), style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.text)),
          if (app.returnedForCompletion && app.data.staffNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Note from OLEDIPO'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(app.data.staffNote, style: const TextStyle(fontSize: 16, height: 1.4)),
              ]),
            ),
          ],
          if (app.returnedForCompletion && onUploadScreen) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/check'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(tr('Fix my answers')),
            ),
          ] else if (app.returnedForCompletion) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/check'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(tr('Fix my answers')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/requirements'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(tr('Fix files and submit')),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}