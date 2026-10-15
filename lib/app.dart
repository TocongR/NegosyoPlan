import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin/admin_shell.dart';
import 'ai/screen_context.dart';
import 'logic/statements.dart';
import 'screens/account_screens.dart';
import 'screens/chatbot_screen.dart';
import 'screens/document_screens.dart';
import 'screens/interview/step_5_statements.dart';
import 'screens/interview/steps_1_to_4.dart';
import 'screens/interview/steps_6_to_9.dart';
import 'screens/upload_screen.dart';
import 'screens/main_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/review_screens.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Every screen in the NegosyoPlan design canvas, by route.
final Map<String, WidgetBuilder> appRoutes = {
  // Account
  '/': (_) => const SplashScreen(), // S00
  '/welcome': (_) => const WelcomeScreen(), // S01
  '/signup': (_) => const SignUpScreen(), // A1
  '/verify': (_) => const VerifyScreen(), // A2
  '/login': (_) => const LoginScreen(), // A3
  '/resume': (_) => const ResumeScreen(), // S01b
  // Start
  '/language': (_) => const LanguageScreen(), // S02
  '/privacy': (_) => const PrivacyScreen(), // S03
  '/passport-start': (_) => const PassportStartScreen(), // S04
  // Guided interview (9 steps)
  '/about': (_) => const AboutYouScreen(), // S05 Step 1
  '/business': (_) => const BusinessScreen(), // S06 Step 2
  '/products': (_) => const ProductsScreen(), // S07 Step 3
  '/costs/prod': (_) => const CostsScreen(kind: 'prod'), // S09a Step 4
  '/costs/resell': (_) => const CostsScreen(kind: 'resell'), // S09b Step 4
  '/costs/service': (_) => const CostsScreen(kind: 'service'), // S09c Step 4
  '/financials': (_) => const FinancialsScreen(), // S10 Step 5
  StatementType.income.route: (_) => const StatementScreen(type: StatementType.income), // S10a
  StatementType.cashFlow.route: (_) => const StatementScreen(type: StatementType.cashFlow), // S10b
  StatementType.balance.route: (_) => const StatementScreen(type: StatementType.balance), // S10c
  '/people': (_) => const PeopleScreen(), // S11 Step 6
  '/projection': (_) => const ProjectionScreen(), // S12 Step 7
  '/loan': (_) => const LoanScreen(), // S13 Step 8
  '/requirements': (_) => const UploadScreen(), // S22c Upload requirements (last, before submitting)
  // Check and review
  '/check': (_) => const CheckAnswersScreen(), // S16
  '/missing': (_) => const MissingScreen(), // S17
  '/warnings': (_) => const WarningsScreen(), // S18
  '/plan': (_) => const PlanReviewScreen(), // S19
  // Documents
  '/consent': (_) => const ConsentScreen(), // S20
  '/documents': (_) => const DocumentsScreen(), // S21
  '/preview': (_) => const PreviewScreen(), // S22
  '/form': (_) => const OfficialFormScreen(), // S22b
  '/tracker': (_) => const TrackerScreen(), // S23
  // Everyday use
  '/home': (_) => const HomeScreen(), // S24
  '/passport': (_) => const PassportScreen(), // S25
  '/statements': (_) => const StatementsScreen(), // S26
  '/settings': (_) => const SettingsScreen(), // S27
  '/chat': (_) => const ChatbotScreen(), // S28
  // OLEDIPO staff
  '/admin': (_) => const AdminShell(),
};

/// Interview routes remembered for "Continue where I left off".
const interviewRoutes = {
  '/about', '/business', '/products', '/costs/prod', '/costs/resell', '/costs/service',
  '/financials', '/people', '/projection', '/loan', '/requirements',
};

class _ResumeObserver extends NavigatorObserver {
  final AppState state;
  _ResumeObserver(this.state);

  void _note(Route<dynamic>? r) {
    final name = r?.settings.name;
    if (name != null && interviewRoutes.contains(name) && state.data.lastRoute != name) {
      // After the frame, so listeners are never notified while the navigator builds.
      Future.microtask(() => state.change((d) => d.lastRoute = name));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _note(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _note(newRoute);
}

class NegosyoPlanApp extends StatefulWidget {
  const NegosyoPlanApp({super.key});
  @override
  State<NegosyoPlanApp> createState() => _NegosyoPlanAppState();
}

class _NegosyoPlanAppState extends State<NegosyoPlanApp> {
  late final _observer = _ResumeObserver(context.read<AppState>());

  @override
  Widget build(BuildContext context) {
    final size = context.select<AppState, int>((s) => s.data.textSize);
    final scale = switch (size) { 1 => 1.15, 2 => 1.3, _ => 1.0 };
    return MaterialApp(
      title: 'NegosyoPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: appRoutes,
      // CurrentScreen lets the Negosyo Helper know which screen you are on.
      navigatorObservers: [_observer, CurrentScreen.instance],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}