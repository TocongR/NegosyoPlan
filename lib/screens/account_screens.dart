import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../logic/checks.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

// S00 Splash · S01 Welcome · A1 Sign up · A2 Verify · A3 Log in · S01b Resume

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1600), _go);
  }

  void _go() {
    if (!mounted) return;
    final app = context.read<AppState>();
    // First launch: choose the language before anything else.
    if (!app.data.langChosen) {
      Navigator.of(context).pushReplacementNamed('/language');
      return;
    }
    Navigator.of(context).pushReplacementNamed(app.hasAccount ? '/login' : '/welcome');
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: InkWell(
            onTap: _go,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 44),
              child: Column(children: [
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOut,
                      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child)),
                      child: Image.asset(logoAsset, width: 168, height: 168, semanticLabel: trn('NegosyoPlan')),
                    ),
                    const SizedBox(height: 22),
                    Text(tr('NegosyoPlan'), style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Text(tr('Plan your negosyo. Get loan-ready.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: AppColors.text2)),
                  ]),
                ),
                const SizedBox(width: 120, child: ProgressBar(0.4, height: 6, background: AppColors.tint)),
                const SizedBox(height: 14),
                Text(tr('Works offline · For EMBRACE loan applicants'), style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ]),
            ),
          ),
        ),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget dot(String t) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 10, right: 14), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          Expanded(child: Text(tr(t), style: const TextStyle(fontSize: 17, height: 1.45, color: AppColors.text2))),
        ]);
    return AppPage(
      back: false,
      footer: Footer(vertical: true, [
        BigButton('Create an account', onPressed: () => Navigator.pushNamed(context, '/signup')),
        BigButton('Log in', style: BtnStyle.secondary, onPressed: () => Navigator.pushNamed(context, '/login')),
        Center(child: LinkButton('OLEDIPO staff sign in', onPressed: () => Navigator.pushNamed(context, '/admin'))),
      ]),
      children: [
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Image.asset(logoAsset, width: 88, height: 88, semanticLabel: trn('NegosyoPlan logo'))),
        Text(tr('NegosyoPlan'), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -0.5)),
        Text(tr('Prepare your business plan and financial statements for an EMBRACE loan.'), style: TextStyle(fontSize: 19, height: 1.5, color: AppColors.text2)),
        const Divider(),
        dot('A business plan in 8 short steps'),
        dot('Type your financial statements once, for every year'),
        dot('Saved on your phone. Works offline.'),
      ],
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // TESTING ONLY: kTestAnswers starts the form filled in (PIN 1234).
  String _name = kTestAnswers ? 'Maria L. Santos' : '', _mobile = kTestAnswers ? '917 123 4567' : '', _pin = kTestAnswers ? '1234' : '';
  bool _show = false, _agreed = true;

  void _create() {
    final m = AppState.normalizeMobile(_mobile);
    if (_name.trim().isEmpty) return toast(context, 'Please type your full name.');
    if (m.length != 11) return toast(context, 'Please type your 10-digit mobile number after +63.');
    if (!RegExp(r'^\d{4}$').hasMatch(_pin)) return toast(context, 'Your PIN must be 4 numbers.');
    if (!_agreed) return toast(context, 'Please agree to the privacy notice.');
    context.read<AppState>().createAccount(name: _name, mobile: m, pin: _pin);
    Navigator.pushNamed(context, '/verify');
  }

  @override
  Widget build(BuildContext context) => AppPage(
        headerTrailing: const LogoMark(),
        footer: Footer(vertical: true, [
          BigButton('Create account', onPressed: _create),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(tr('Already have an account? '), style: TextStyle(fontSize: 17)),
            LinkButton('Log in', onPressed: () => Navigator.pushReplacementNamed(context, '/login')),
          ]),
        ]),
        gap: 26,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H1('Create your account'),
            SizedBox(height: 8),
            Text(tr('No email needed. Your account works even without internet.'), style: AppText.lead),
          ]),
          FieldBlock(label: 'Full name', example: 'Example: Maria L. Santos', child: AppTextField(initial: _name, hint: 'Your full name', onChanged: (v) => _name = v)),
          FieldBlock(label: 'Mobile number', child: AppTextField(initial: _mobile, hint: '9XX XXX XXXX', prefix: '+63 ', keyboardType: TextInputType.phone, onChanged: (v) => _mobile = v)),
          FieldBlock(
            label: 'Create a 4-digit PIN',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppTextField(
                initial: _pin,
                hint: '••••',
                obscure: !_show,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, letterSpacing: 18),
                onChanged: (v) => _pin = v,
              ),
              Row(children: [
                Expanded(child: Text(tr('You will use this to open the app.'), style: AppText.small)),
                TextButton(onPressed: () => setState(() => _show = !_show), child: Text(tr(_show ? 'Hide' : 'Show'))),
              ]),
            ]),
          ),
          Row(children: [
            Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
            Text(tr('I agree to the '), style: TextStyle(fontSize: 17)),
            LinkButton('privacy notice', onPressed: () => Navigator.pushNamed(context, '/privacy', arguments: true)),
          ]),
        ],
      );
}

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = app.data.mobile;
    final masked = m.length >= 11 ? '+63 ${m.substring(1, 4)} ••• ${m.substring(7)}' : '+63 ${m.isEmpty ? '•••' : m}';
    return AppPage(
      headerTrailing: const LogoMark(),
      gap: 26,
      footer: Footer([
        BigButton('Verify later', style: BtnStyle.secondary, onPressed: () => Navigator.pushNamed(context, '/privacy')),
        BigButton('Verify', onPressed: () {
          // TODO(server): check the SMS code with the OLEDIPO server.
          app.change((d) => d.verified = true);
          Navigator.pushNamed(context, '/privacy');
        }),
      ]),
      children: [
        const Align(alignment: Alignment.centerLeft, child: IconTile(Icons.sms_outlined, size: 64)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H1('Check your messages'),
          const SizedBox(height: 8),
          Text.rich(TextSpan(style: AppText.lead, children: [
            TextSpan(text: trn('We sent a 6-digit code to ')),
            TextSpan(text: trn(masked), style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
        ]),
        FieldBlock(
          label: 'Enter the code',
          example: 'Did not get it? You can ask for a new code in 0:45.',
          child: AppTextField(
            initial: kTestAnswers ? '123456' : '',
            hint: '––––––',
            maxLength: 6,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 20),
            onChanged: (_) {},
          ),
        ),
        const NoteBox('No signal? You can verify later. Everything you enter stays saved on this phone.'),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _mobile = '';
  String _pin = kTestAnswers ? '1234' : ''; // TESTING ONLY

  void _press(String k) => setState(() {
        if (k == 'del') {
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        } else if (k == 'clr') {
          _pin = '';
        } else if (_pin.length < 4) {
          _pin += k;
        }
      });

  void _login() {
    final app = context.read<AppState>();
    final mobile = _mobile.isEmpty ? app.data.mobile : _mobile;
    if (app.login(mobile, _pin)) {
      Navigator.pushNamedAndRemoveUntil(context, '/resume', (r) => false);
    } else {
      setState(() => _pin = '');
      toast(context, app.hasAccount ? 'Wrong mobile number or PIN. Please try again.' : 'No account on this phone yet. Please create one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget key(String k) {
      final ghost = k == 'del' || k == 'clr';
      return SizedBox(
        height: 60,
        child: TextButton(
          onPressed: () => _press(k),
          style: TextButton.styleFrom(
            backgroundColor: ghost ? Colors.transparent : AppColors.surface2,
            foregroundColor: AppColors.text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: TextStyle(fontSize: ghost ? 16 : 26, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
          ),
          child: k == 'del' ? Icon(Icons.backspace_outlined, semanticLabel: trn('Delete')) : Text(tr(k == 'clr' ? 'Clear' : k)),
        ),
      );
    }

    return AppPage(
      title: 'Welcome back',
      headerTrailing: const LogoMark(),
      footer: Footer(vertical: true, [
        BigButton('Log in', onPressed: _pin.length == 4 ? _login : null),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(tr('New here? '), style: TextStyle(fontSize: 17)),
          LinkButton('Create an account', onPressed: () => Navigator.pushReplacementNamed(context, '/signup')),
        ]),
      ]),
      children: [
        FieldBlock(
          label: 'Mobile number',
          child: AppTextField(
            initial: app.data.mobile.startsWith('0') ? app.data.mobile.substring(1) : app.data.mobile,
            hint: '9XX XXX XXXX',
            prefix: '+63 ',
            keyboardType: TextInputType.phone,
            onChanged: (v) => _mobile = v,
          ),
        ),
        Row(children: [
          Expanded(child: Text(tr('Your 4-digit PIN'), style: AppText.label)),
          LinkButton('Forgot PIN?', onPressed: () => toast(context, 'Visit the OLEDIPO office to reset your PIN.')),
        ]),
        Semantics(
          label: trn('${_pin.length} of 4 digits entered'),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
          ]),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [for (final k in const ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'clr', '0', 'del']) key(k)],
        ),
      ],
    );
  }
}

class ResumeScreen extends StatelessWidget {
  const ResumeScreen({super.key});

  static const _routeNames = {
    '/about': 'Step 1 · About you',
    '/business': 'Step 2 · Your business',
    '/products': 'Step 3 · What you sell',
    '/costs/prod': 'Step 4 · Making your product',
    '/costs/resell': 'Step 4 · Buying your goods',
    '/costs/service': 'Step 4 · Your service supplies',
    '/financials': 'Step 5 · Financial statements',
    '/people': 'Step 6 · Your workers',
    '/projection': 'Step 7 · Financial projection',
    '/loan': 'Step 8 · Your loan',
    '/requirements': 'Upload your requirements',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pct = readiness(app);
    final at = _routeNames[app.data.lastRoute] ?? 'Step 1 · About you';
    return AppPage(
      back: false,
      gap: 28,
      footer: Footer(vertical: true, [
        BigButton('Continue where I left off', onPressed: () => Navigator.pushNamed(context, _routeNames.containsKey(app.data.lastRoute) ? app.data.lastRoute : '/about')),
        BigButton('Go to Home', style: BtnStyle.secondary, onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
      ]),
      children: [
        const LogoMark(size: 40),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Welcome!'), style: TextStyle(fontSize: 18, color: AppColors.muted)),
          Text(tr(app.firstName.isEmpty ? 'Hello' : app.firstName), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
        ]),
        CardBox(
          radius: 20,
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
            Text(tr('You stopped at'), style: TextStyle(fontSize: 16, color: AppColors.muted)),
            Text(tr(at), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ProgressBar(pct, height: 10),
            Text(tr('Your loan papers are ${(pct * 100).round()}% done. Everything you entered is saved on this phone.'), style: AppText.lead),
          ], 14)),
        ),
        if (!app.data.v.containsKey('bn'))
          NoteBox('Want to see how it works first?',
              title: 'Try it with sample data',
              action: LinkButton('Fill with a sample business', onPressed: () {
                app.loadSample();
                toast(context, 'Sample answers added. You can change them anytime.');
              })),
      ],
    );
  }
}
