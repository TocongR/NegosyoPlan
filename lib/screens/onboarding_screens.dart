import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

// S02 Language (first screen after the splash) · S03 Privacy · S04 Create Enterprise Passport

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const langs = [('hil', 'Hiligaynon', 'Ilonggo'), ('fil', 'Filipino', 'Tagalog (English muna sa ngayon)'), ('en', 'English', 'English')];
    return AppPage(
      title: 'Choose your language',
      back: app.data.langChosen,
      gap: 26,
      footer: Footer([
        BigButton('Continue', onPressed: () {
          final first = !app.data.langChosen;
          app.change((d) => d.langChosen = true);
          if (first) {
            // First launch: the language is set before sign up or log in.
            Navigator.pushReplacementNamed(context, app.hasAccount ? '/login' : '/welcome');
          } else {
            Navigator.maybePop(context);
          }
        }),
      ]),
      children: [
        Text(tr('Pili sang lenguahe · Piliin ang wika'), style: AppText.lead),
        for (final (id, name, hint) in langs)
          Semantics(
            selected: app.data.lang == id,
            button: true,
            child: Material(
              color: app.data.lang == id ? AppColors.tint : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: app.data.lang == id ? AppColors.primary : AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => app.change((d) => d.lang = id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(name), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                        Text(tr(hint), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                      ]),
                    ),
                    if (app.data.lang == id) const Icon(Icons.check, color: AppColors.primary, size: 28),
                  ]),
                ),
              ),
            ),
          ),
        Text(tr('You can change this anytime in Settings.'), style: TextStyle(fontSize: 16, color: AppColors.muted)),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // When opened from the sign-up link, only show the notice.
    final readOnly = ModalRoute.of(context)?.settings.arguments == true;
    Widget point(IconData icon, String text) => Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(tr(text), style: const TextStyle(fontSize: 18, height: 1.4))),
        ]);
    return AppPage(
      title: 'Your information is safe',
      gap: 20,
      footer: readOnly
          ? null
          : Footer([
              BigButton('I agree', onPressed: app.data.privacyAgreed ? () => Navigator.pushNamed(context, '/passport-start') : null),
            ]),
      children: [
        point(Icons.smartphone, 'Your data stays on this phone.'),
        point(Icons.lock_outline, 'Nothing is shared unless you say yes.'),
        point(Icons.delete_outline, 'You can delete your data anytime.'),
        point(Icons.info_outline, 'This app helps you prepare. It does not approve loans.'),
        if (!readOnly) ...[
          const SizedBox(height: 10),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            radius: 14,
            child: CheckboxListTile(
              value: app.data.privacyAgreed,
              onChanged: (v) => app.change((d) => d.privacyAgreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(tr('I understand and agree'), style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ],
    );
  }
}

class PassportStartScreen extends StatelessWidget {
  const PassportStartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget part(int n, String t, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
              child: Text(tr('$n'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text2)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(tr(t), style: const TextStyle(fontSize: 18))),
          ]),
        );
    return AppPage(
      title: 'Your Enterprise Passport',
      headerTrailing: const LogoMark(),
      footer: Footer([BigButton('Begin', onPressed: () => Navigator.pushNamed(context, '/about'))]),
      children: [
        Text(tr('Answer once. Your answers fill your business plan and loan forms. You type your financial statements yourself.'), style: AppText.lead),
        Column(children: [
          part(1, 'About you'),
          part(2, 'Your business'),
          part(3, 'Money: costs, statements, loan'),
          part(4, 'Requirements: business permit, barangay certificate and training certificates', last: true),
        ]),
        Text(tr('About 30–45 minutes. You can stop and continue later.'), style: TextStyle(fontSize: 16, color: AppColors.muted)),
      ],
    );
  }
}
