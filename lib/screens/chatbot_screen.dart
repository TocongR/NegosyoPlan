import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/gemini_config.dart';
import '../ai/gemini_service.dart';
import '../ai/screen_context.dart';
import '../logic/checks.dart';
import '../logic/format.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

/// Offline answers, used only when the AI is off (no Gemini key) or as
/// extra help when there is no internet.
class HelperBrain {
  static const answers = <(List<String>, String, String)>[
    (
      ['beginning inventory', 'inventory', 'stock', 'imbentaryo', 'paninda'],
      'What is “Beginning inventory”?',
      'It is the value of the stock you had on the first day of the year.\nExample: on January 1 you had flour, sugar and packs worth ₱20,000. Type 20000.'
    ),
    (
      ['net income', 'profit', 'kita', 'ganansya', 'ginansya'],
      'What is “Net income”?',
      'It is what is left after you pay for everything.\nOn your income statement it is Gross income minus Total operating expenses. The app adds it up for you.'
    ),
    (
      ['depreciation', 'balor', 'nadula', 'nagabanaba'],
      'What is “Accumulated depreciation”?',
      'Things like a motorcycle or freezer lose value as they get older. Accumulated depreciation is how much value they have lost so far.\nIf you do not know, ask your bookkeeper or put 0 for new items.'
    ),
    (
      ['annex c', 'residency', 'barangay', 'certificate', 'sertipiko', 'kapitan'],
      'What is the Certificate of Residency and Business Operation?',
      'It is Annex C. Your barangay captain signs it to say you live in the barangay and your business is running there.\nNegosyoPlan fills in the form for you from your answers. Print it, have it signed, then upload it as a PDF at the end, before you submit.'
    ),
    (
      ['itr', 'sales last year', 'records', 'find', 'numero', 'rekord', 'diin', 'benta'],
      'Where do I find my numbers?',
      'Look at your ITR, your sales notebook, receipts or bank book.\nIf you have a bookkeeper, ask them for your income statement, cash flow and balance sheet. Copy the lines into the app.'
    ),
    (
      ['person', 'staff', 'oledipo', 'human', 'call', 'tawo', 'opisina', 'istorya'],
      'Can I talk to a person?',
      'Yes. Visit or call the OLEDIPO office during office hours. Bring your phone so staff can see your answers.'
    ),
  ];

  static String? match(String question) {
    final t = question.toLowerCase();
    for (final (keys, _, answer) in answers) {
      if (keys.any(t.contains)) return answer;
    }
    return null;
  }

  static String reply(String question) =>
      match(question) ?? 'Sorry, I am not sure about that yet. Please ask OLEDIPO staff.';
}

/// One message in the chat.
class _Msg {
  _Msg(this.me, this.text, {this.offline = false});
  final bool me;
  final bool offline; // pre-written, not from the AI
  String text;
  bool error = false;
}

/// One chat per screen, kept while the app is open. Going to another screen
/// starts a new chat, so answers never mix up screens.
class _Memory {
  static final Map<String, List<_Msg>> byScreen = {};
}

/// S28 · Negosyo Helper. Opens from the helper button and talks only about
/// the screen the owner came from. It changes an answer only when the owner
/// taps "Put this in the form" under a suggestion.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final ScreenHelp _help = CurrentScreen.instance.help;
  late final List<_Msg> _msgs = _Memory.byScreen.putIfAbsent(CurrentScreen.instance.key, () => []);
  bool _busy = false;

  bool get _ai => GeminiConfig.isConfigured;

  @override
  void initState() {
    super.initState();
    if (_msgs.isEmpty) _greet();
    _toBottom(jump: true);
  }

  void _greet() {
    final name = context.read<AppState>().firstName;
    final example = _help.chips.isEmpty ? 'What should I type here?' : _help.chips.first.text;
    _msgs.add(_Msg(
      false,
      'Hello${name.isEmpty ? '' : ' $name'}! I can help you with “${_help.title}”.\n'
      'Ask me anything in your own words. For example: “$example”',
      offline: true,
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      jump ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _ask(String q) async {
    final question = q.trim();
    if (question.isEmpty || _busy) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    setState(() => _msgs.add(_Msg(true, question)));

    if (!_ai) {
      setState(() => _msgs.add(_Msg(false, HelperBrain.reply(question), offline: true)));
      _toBottom();
      return;
    }

    final app = context.read<AppState>();
    final history = [
      for (final m in _msgs)
        if (!m.error && !m.offline && m.text.trim().isNotEmpty) ChatMessage(m.me ? ChatRole.user : ChatRole.model, m.text),
    ];
    final reply = _Msg(false, '');
    setState(() {
      _msgs.add(reply);
      _busy = true;
    });
    _toBottom();

    try {
      await for (final chunk in GeminiService.instance.streamReply(
        history: history,
        systemPrompt: buildSystemPrompt(app, _help),
      )) {
        if (!mounted) return;
        setState(() => reply.text += chunk);
        _toBottom();
      }
      if (reply.text.trim().isEmpty) throw GeminiFailure('Sorry, I could not answer that. Please ask in another way.');
    } catch (e) {
      final msg = switch (e) {
        GeminiFailure f => f.message,
        TimeoutException _ => 'The helper took too long. Check your internet and try again.',
        _ => 'No internet connection. Please try again.',
      };
      final offline = HelperBrain.match(question);
      reply
        ..error = true
        ..text = offline == null ? msg : '$msg\n\n$offline';
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  /// Puts one suggested answer into the form, then goes back to the screen.
  void _putInForm(String key, String value) {
    var v = value.trim();
    if (amountKeys.contains(key)) v = v.replaceAll(RegExp(r'[^0-9.]'), '');
    context.read<AppState>().setVal(key, v);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text('${tr('Added to')}: ${tr(_help.writable[key] ?? key)}', style: const TextStyle(fontSize: 16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
            child: Image.asset(logoAsset),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Negosyo Helper'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(tr(_help.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: trn('Start over'),
            onPressed: _busy
                ? null
                : () => setState(() {
                      _msgs.clear();
                      _greet();
                    }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Wrap(spacing: 8, children: [
              for (final (id, name) in const [('en', 'English'), ('hil', 'Hiligaynon'), ('fil', 'Filipino')])
                ChoiceChip(
                  label: Text(tr(name)),
                  selected: app.data.lang == id,
                  showCheckmark: false,
                  onSelected: (_) => app.change((d) => d.lang = id),
                ),
            ]),
          ),
          if (!_ai)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warnBorder),
              ),
              child: const Text(
                'AI is OFF: the app was started without the Gemini key, so only pre-written answers work. '
                'Run with: flutter run --dart-define-from-file=env.json',
                style: TextStyle(fontSize: 14, color: AppColors.estimateFg),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                for (var i = 0; i < _msgs.length; i++) _message(_msgs[i], streaming: _busy && i == _msgs.length - 1),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: _ask,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: trn('Type your question'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(27)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(27), borderSide: const BorderSide(color: AppColors.borderStrong)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: trn('Send'),
                onPressed: _busy ? null : () => _ask(_input.text),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(54, 54)),
                icon: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.arrow_forward),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              tr('The helper can make mistakes. Check before you use its answers. For your loan decision, ask OLEDIPO.'),
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ messages

  Widget _message(_Msg m, {required bool streaming}) {
    if (m.me) return _bubble(Text(m.text, style: _style(Colors.white)), me: true);
    if (m.offline || m.error) {
      return _bubble(Text(m.offline ? tr(m.text) : m.text, style: _style(m.error ? AppColors.missingFg : AppColors.text)), error: m.error);
    }
    if (m.text.isEmpty && streaming) return _bubble(Text(tr('Thinking…'), style: _style(AppColors.muted)));

    // Split the reply into normal text and suggested answers.
    final out = <Widget>[];
    for (final part in _parse(m.text, streaming: streaming)) {
      if (part.key == null) {
        if (part.text.trim().isNotEmpty) out.add(_bubble(_RichReply(text: part.text.trim(), style: _style(AppColors.text))));
      } else if (part.pending) {
        out.add(_bubble(Text(tr('Writing a suggestion…'), style: _style(AppColors.muted))));
      } else {
        out.add(_suggestion(part.key!, part.text.trim(), done: !streaming));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }

  TextStyle _style(Color c) => TextStyle(fontSize: 17, height: 1.45, color: c);

  Widget _bubble(Widget child, {bool me = false, bool error = false}) => Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: error ? AppColors.missingBg : (me ? AppColors.primary : const Color(0xFFF2F5F3)),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(me ? 18 : 4),
              topRight: Radius.circular(me ? 4 : 18),
              bottomLeft: const Radius.circular(18),
              bottomRight: const Radius.circular(18),
            ),
          ),
          child: child,
        ),
      );

  /// The box with one suggested answer and the "Put this in the form" button.
  Widget _suggestion(String key, String value, {required bool done}) {
    final label = _help.writable[key];
    if (label == null) return _bubble(Text(value, style: _style(AppColors.text))); // unknown field: show as text
    final app = context.watch<AppState>();
    final isAmount = amountKeys.contains(key);
    final shown = isAmount ? peso(amt(value)) : value;
    final current = app.val(key).trim();
    final already = current.isNotEmpty && current == (isAmount ? value.replaceAll(RegExp(r'[^0-9.]'), '') : value);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tint2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.edit_note, color: AppColors.primary, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${tr('Suggested answer for')}:\n${tr(label)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.3)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tintBorder),
          ),
          child: SelectableText(shown, style: TextStyle(fontSize: isAmount ? 22 : 17, height: 1.45, fontWeight: isAmount ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (done) ...[
          const SizedBox(height: 12),
          if (already)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(tr('This is already in the form'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ])
          else ...[
            if (current.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(tr('This will replace what you typed before.'), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ),
            FilledButton.icon(
              onPressed: () => _putInForm(key, value),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
              ),
              icon: const Icon(Icons.check),
              label: Text(tr('Put this in the form')),
            ),
            const SizedBox(height: 4),
            Text(tr('Not right? Tell me what to change.'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
        ],
      ]),
    );
  }
}

/// A piece of the AI reply: plain text, or a suggested answer for [key].
class _Part {
  _Part.text(this.text)
      : key = null,
        pending = false;
  _Part.fill(this.key, this.text, {this.pending = false});
  final String? key;
  final String text;
  final bool pending; // suggestion still being written
}

final _fillRe = RegExp(r'<fill\s+field\s*=\s*"([A-Za-z0-9_]+)"\s*>([\s\S]*?)</fill>');
final _openRe = RegExp(r'<fill\s+field\s*=\s*"([A-Za-z0-9_]+)"\s*>([\s\S]*)$');

List<_Part> _parse(String s, {required bool streaming}) {
  final parts = <_Part>[];
  var last = 0;
  for (final m in _fillRe.allMatches(s)) {
    if (m.start > last) parts.add(_Part.text(s.substring(last, m.start)));
    parts.add(_Part.fill(m.group(1), m.group(2)!));
    last = m.end;
  }
  var rest = s.substring(last);

  // A suggestion that is not finished yet (or the AI forgot to close it).
  final open = _openRe.firstMatch(rest);
  if (open != null) {
    if (open.start > 0) parts.add(_Part.text(rest.substring(0, open.start)));
    parts.add(_Part.fill(open.group(1), open.group(2)!, pending: streaming));
    return parts;
  }

  // Hide a half-written "<fil…" tag while the reply is still coming in.
  if (streaming) {
    final lt = rest.lastIndexOf('<');
    if (lt != -1 && '<fill'.startsWith(rest.substring(lt).split(' ').first)) rest = rest.substring(0, lt);
  }
  if (rest.isNotEmpty) parts.add(_Part.text(rest));
  return parts;
}

/// Shows **bold**, "- " bullets, "1." lists and # headings from the AI.
class _RichReply extends StatelessWidget {
  const _RichReply({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        out.add(const SizedBox(height: 6));
        continue;
      }
      final h = RegExp(r'^#{1,6}\s+(.*)').firstMatch(line);
      final b = RegExp(r'^\s*[-*•]\s+(.*)').firstMatch(line);
      final n = RegExp(r'^\s*(\d+)[.)]\s+(.*)').firstMatch(line);
      if (h != null) {
        out.add(Text.rich(_spans(h.group(1)!, style.copyWith(fontWeight: FontWeight.w700))));
      } else if (b != null || n != null) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(b != null ? '•' : '${n!.group(1)}.', style: style)),
            Expanded(child: Text.rich(_spans(b != null ? b.group(1)! : n!.group(2)!, style))),
          ]),
        ));
      } else {
        out.add(Text.rich(_spans(line, style)));
      }
    }
    return SelectionArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: out));
  }

  TextSpan _spans(String s, TextStyle base) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in RegExp(r'\*\*(.+?)\*\*').allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}