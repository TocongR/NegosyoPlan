import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'gemini_service.dart';

/// What the assistant knows about the screen the user is on.
class AssistantScreenInfo {
  const AssistantScreenInfo({
    required this.screen,
    this.description,
    this.data,
    this.suggestions = const [],
    this.onUseText,
    this.useTextLabel,
  });

  /// e.g. "Income Statement"
  final String screen;

  /// What the screen is for and what each field means.
  final String? description;

  /// Returns the user's current inputs (read at the moment they ask).
  final Map<String, dynamic> Function()? data;

  /// Quick-question chips shown in the chat for this screen.
  final List<String> suggestions;

  /// If set, AI replies get a button that puts the text into your screen
  /// (e.g. fill a "Business description" field).
  final void Function(String text)? onUseText;
  final String? useTextLabel;
}

/// Holds the current screen info and the chat conversation.
class AssistantController extends ChangeNotifier {
  AssistantController._();
  static final AssistantController instance = AssistantController._();

  final List<_Entry> _stack = [];
  final List<ChatMessage> messages = [];

  bool isReplying = false;
  bool sheetOpen = false;

  AssistantScreenInfo? get current => _stack.isEmpty ? null : _stack.last.info;

  // ------------------------------------------------ screen registration

  Object register(AssistantScreenInfo info) {
    final token = Object();
    _stack.add(_Entry(token, info));
    _notifyLater();
    return token;
  }

  void update(Object token, AssistantScreenInfo info) {
    final i = _stack.indexWhere((e) => e.token == token);
    if (i == -1) return;
    _stack[i] = _Entry(token, info);
    _notifyLater();
  }

  void unregister(Object token) {
    _stack.removeWhere((e) => e.token == token);
    _notifyLater();
  }

  void setSheetOpen(bool open) {
    sheetOpen = open;
    _notifyLater();
  }

  // Avoids "setState() called during build" when screens register.
  void _notifyLater() => scheduleMicrotask(notifyListeners);

  // ------------------------------------------------------- conversation

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || isReplying) return;

    messages.add(ChatMessage(ChatRole.user, question));
    final reply = ChatMessage(ChatRole.model, '');
    messages.add(reply);
    isReplying = true;
    notifyListeners();

    try {
      final history = messages.where((m) => m != reply).toList();
      await for (final chunk in GeminiService.instance.streamReply(
        history: history,
        systemPrompt: buildSystemPrompt(),
      )) {
        reply.text += chunk;
        notifyListeners();
      }
      if (reply.text.trim().isEmpty) {
        reply.text = "Sorry, I couldn't answer that. Try asking another way.";
        reply.isError = true;
      }
    } on GeminiFailure catch (e) {
      reply
        ..text = e.message
        ..isError = true;
    } on TimeoutException {
      reply
        ..text = 'The AI took too long to answer. Check your internet and try again.'
        ..isError = true;
    } catch (_) {
      reply
        ..text = 'No connection to the AI. Check your internet and try again.'
        ..isError = true;
    } finally {
      isReplying = false;
      notifyListeners();
    }
  }

  void clearChat() {
    if (isReplying) return;
    messages.clear();
    notifyListeners();
  }

  // ------------------------------------------------------- the "brain"

  String buildSystemPrompt() {
    final info = current;
    final buf = StringBuffer(_basePrompt);

    if (info != null) {
      buf
        ..writeln()
        ..writeln('=== CURRENT SCREEN ===')
        ..writeln('Screen: ${info.screen}');
      if (info.description != null && info.description!.isNotEmpty) {
        buf.writeln('About this screen: ${info.description}');
      }
      final data = _safeData(info);
      if (data != null) {
        buf
          ..writeln("User's current inputs on this screen (JSON, may be "
              'incomplete or empty):')
          ..writeln(data);
      }
      if (info.onUseText != null) {
        buf.writeln('The user can tap a button to paste your reply into the '
            'screen. When asked to write or draft something, reply with ONLY '
            'the finished text, no intro or closing lines.');
      }
    }
    return buf.toString();
  }

  String? _safeData(AssistantScreenInfo info) {
    if (info.data == null) return null;
    try {
      final map = info.data!();
      if (map.isEmpty) return null;
      return const JsonEncoder.withIndent(' ')
          .convert(map.map((k, v) => MapEntry(k, _jsonSafe(v))));
    } catch (_) {
      return null;
    }
  }

  Object? _jsonSafe(Object? v) {
    if (v == null || v is num || v is bool || v is String) return v;
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) return v.map((k, val) => MapEntry('$k', _jsonSafe(val)));
    if (v is Iterable) return v.map(_jsonSafe).toList();
    return v.toString();
  }

  static const String _basePrompt = '''
You are "Negosyo Buddy", the friendly assistant inside NegosyoPlan, a mobile app that helps Filipino micro and small entrepreneurs plan their business, prepare financial statements and write a business plan.

Who you help: first-time and small business owners (sari-sari stores, food stalls, online sellers, services). Many have no accounting background.

How to answer:
- Reply in the same language the user uses (English, Filipino/Tagalog, Taglish, Hiligaynon, Cebuano, etc.).
- Keep answers short and phone-friendly: a few sentences or a short bullet list. Offer to go deeper instead of writing long essays.
- Teach simply. Explain terms with everyday Filipino business examples (e.g. a sari-sari store or a milk tea stall).
- Use Philippine pesos (₱) for money.
- When the user asks what to put in a field, explain what it means, give a realistic sample value, and tell them how to compute their own.
- When the user's inputs are provided, use their actual numbers. Do the math step by step and double-check it. Point out anything that looks off (e.g. expenses larger than sales, missing fields).
- Never invent the user's own figures and present them as real. Clearly label examples as samples.
- When writing business plan sections, write in clear, simple, professional English unless asked otherwise, and base it on the user's details. Ask for missing key details if needed.
- For taxes, permits (DTI, BIR, Mayor's permit, barangay clearance) and loans, give general guidance and remind them to confirm with the agency or an accountant, since rules change.
- Formatting: plain text, **bold** for key terms, "- " for bullets. No tables, no code blocks.
- Stay on topic: business, money, planning and how to use this app. Politely steer back if asked about unrelated things.
''';
}

class _Entry {
  _Entry(this.token, this.info);
  final Object token;
  final AssistantScreenInfo info;
}

/// Wrap a screen with this so the assistant knows where the user is.
///
/// ```dart
/// return AssistantScope(
///   screen: 'Income Statement',
///   description: 'Shows sales, cost of goods sold, expenses and net income.',
///   data: () => {'sales': salesCtrl.text, 'expenses': expensesCtrl.text},
///   suggestions: ['What is cost of goods sold?', 'Summarize my income statement'],
///   child: Scaffold(...),
/// );
/// ```
class AssistantScope extends StatefulWidget {
  const AssistantScope({
    super.key,
    required this.screen,
    this.description,
    this.data,
    this.suggestions = const [],
    this.onUseText,
    this.useTextLabel,
    required this.child,
  });

  final String screen;
  final String? description;
  final Map<String, dynamic> Function()? data;
  final List<String> suggestions;
  final void Function(String text)? onUseText;
  final String? useTextLabel;
  final Widget child;

  @override
  State<AssistantScope> createState() => _AssistantScopeState();
}

class _AssistantScopeState extends State<AssistantScope> {
  late final Object _token;

  AssistantScreenInfo get _info => AssistantScreenInfo(
        screen: widget.screen,
        description: widget.description,
        data: widget.data,
        suggestions: widget.suggestions,
        onUseText: widget.onUseText,
        useTextLabel: widget.useTextLabel,
      );

  @override
  void initState() {
    super.initState();
    _token = AssistantController.instance.register(_info);
  }

  @override
  void didUpdateWidget(covariant AssistantScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    AssistantController.instance.update(_token, _info);
  }

  @override
  void dispose() {
    AssistantController.instance.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}