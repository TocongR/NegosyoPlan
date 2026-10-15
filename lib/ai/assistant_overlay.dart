import 'package:flutter/material.dart';

import 'assistant_chat_sheet.dart';
import 'assistant_controller.dart';

/// Give this to MaterialApp(navigatorKey: appNavigatorKey) so the
/// assistant can open from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Opens the assistant chat. Pass [prompt] to ask something right away,
/// e.g. from a "Write with AI" button:
///   openAssistant(prompt: 'Write my business description');
Future<void> openAssistant({String? prompt}) async {
  final ctx = appNavigatorKey.currentContext;
  if (ctx == null) return;
  final controller = AssistantController.instance;
  if (controller.sheetOpen) return;

  controller.setSheetOpen(true);
  if (prompt != null && prompt.trim().isNotEmpty) {
    controller.send(prompt);
  }
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => const AssistantChatSheet(),
  );
  controller.setSheetOpen(false);
}

/// Floating, draggable assistant button shown over every screen that is
/// wrapped in an AssistantScope. Use in MaterialApp.builder.
class AssistantOverlay extends StatefulWidget {
  const AssistantOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<AssistantOverlay> {
  static const double _size = 56;
  Offset? _pos; // top-left of the button

  @override
  Widget build(BuildContext context) {
    final controller = AssistantController.instance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = MediaQuery.paddingOf(context);
        final maxX = constraints.maxWidth - _size - 12;
        final maxY = constraints.maxHeight - _size - 12 - pad.bottom;
        final minY = 12 + pad.top;
        final pos = _pos ?? Offset(maxX, maxY - 88);

        return Stack(
          children: [
            widget.child,
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final show = controller.current != null && !controller.sheetOpen;
                if (!show) return const SizedBox.shrink();
                return Positioned(
                  left: pos.dx.clamp(12.0, maxX),
                  top: pos.dy.clamp(minY, maxY),
                  child: GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      final next = (_pos ?? pos) + d.delta;
                      _pos = Offset(
                        next.dx.clamp(12.0, maxX),
                        next.dy.clamp(minY, maxY),
                      );
                    }),
                    child: _AssistantButton(onTap: () => openAssistant()),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AssistantButton extends StatelessWidget {
  const _AssistantButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _AssistantOverlayState._size,
          height: _AssistantOverlayState._size,
          child: Icon(Icons.auto_awesome, color: scheme.onPrimary),
        ),
      ),
    );
  }
}