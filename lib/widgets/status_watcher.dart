import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/tr.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// The app's navigator, so a pop-up can be shown from anywhere.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Remembers which screen is on top, so the pop-up never covers the
/// start, language or log-in screens.
class TopRouteObserver extends NavigatorObserver {
  static String? top;
  void _set(Route<dynamic>? r) {
    if (r is PageRoute) top = r.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);
}

/// When OLEDIPO staff return or accept the application, tells the owner
/// once with a pop-up (while the app is open, or the next time it opens).
/// Wrap the app's navigator with it (MaterialApp.builder).
class StatusWatcher extends StatefulWidget {
  final Widget child;
  const StatusWatcher({super.key, required this.child});
  @override
  State<StatusWatcher> createState() => _StatusWatcherState();
}

class _StatusWatcherState extends State<StatusWatcher> {
  static const _quiet = {null, '/', '/language', '/welcome', '/signup', '/verify', '/login', '/privacy'};
  bool _showing = false;
  bool _waiting = false;
  late final AppState _app = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _app.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _app.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_showing || !_app.hasStatusNews) return;
    if (_quiet.contains(TopRouteObserver.top)) {
      // Try again shortly, after the owner reaches a normal screen.
      if (_waiting) return;
      _waiting = true;
      Future.delayed(const Duration(seconds: 2), () {
        _waiting = false;
        if (mounted) _check();
      });
      return;
    }
    final ctx = appNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    _showing = true;
    _show(ctx).whenComplete(() => _showing = false);
  }

  Future<void> _show(BuildContext ctx) async {
    final returned = _app.returnedForCompletion;
    final note = _app.data.staffNote.trim();
    _app.markStatusSeen();
    final go = await showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        icon: Icon(returned ? Icons.assignment_return_outlined : Icons.verified_outlined,
            size: 40, color: returned ? AppColors.missingFg : AppColors.primary),
        title: Text(tr(returned ? 'OLEDIPO returned your application' : 'Your application is accepted')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              tr(returned
                  ? 'OLEDIPO needs something more from you. Fix it, then submit again.'
                  : 'Your papers are complete. The EMBRACE committee will now decide on your loan.'),
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            if (returned && note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.missingBg, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Note from OLEDIPO'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.missingFg)),
                  const SizedBox(height: 4),
                  Text(note, style: const TextStyle(fontSize: 16, height: 1.4)),
                ]),
              ),
            ],
          ]),
        ),
        actions: returned
            ? [
                TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Later'))),
                FilledButton(onPressed: () => Navigator.pop(c, '/requirements'), child: Text(tr('Fix now'))),
              ]
            : [FilledButton(onPressed: () => Navigator.pop(c, '/tracker'), child: Text(tr('OK')))],
      ),
    );
    if (go != null) appNavigatorKey.currentState?.pushNamed(go);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}