import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

/// S28 · Negosyo Helper. Explains form questions in simple words.
/// It never types or changes the owner's answers. Understands simple
/// English and Hiligaynon words; answers show in the owner's language.
///
/// The answers below are pre-written. To connect a real assistant, replace
/// [HelperBrain.reply] with a call to your server and keep it limited to the
/// OLEDIPO forms.
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

  static String reply(String question) {
    final t = question.toLowerCase();
    for (final (keys, _, answer) in answers) {
      if (keys.any(t.contains)) return answer;
    }
    return 'Sorry, I am not sure about that yet. Try one of the questions below, or ask OLEDIPO staff.';
  }
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final List<(bool, String)> _msgs; // (fromMe, text)

  @override
  void initState() {
    super.initState();
    final name = context.read<AppState>().firstName;
    _msgs = [(false, 'Hello${name.isEmpty ? '' : ' $name'}! I can explain any question in NegosyoPlan in simple words.\nTap a question below or type your own.')];
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(String q, [String? a]) {
    if (q.trim().isEmpty) return;
    setState(() {
      _msgs.add((true, q.trim()));
      _msgs.add((false, a ?? HelperBrain.reply(q)));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final asked = _msgs.where((m) => m.$1).map((m) => m.$2).toSet();
    final chips = HelperBrain.answers.where((a) => !asked.contains(a.$2)).toList();
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
              Text(tr('Negosyo Helper'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(tr('Ask about any question in the form'), style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ]),
          ),
        ]),
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
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              children: [
                for (final (me, text) in _msgs)
                  Align(
                    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: me ? AppColors.primary : const Color(0xFFF2F5F3),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(me ? 18 : 4),
                          topRight: Radius.circular(me ? 4 : 18),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                      ),
                      child: Text(tr(text), style: TextStyle(fontSize: 17, height: 1.45, color: me ? Colors.white : AppColors.text)),
                    ),
                  ),
                if (chips.isNotEmpty) ...[
                  Padding(padding: EdgeInsets.only(top: 6, bottom: 8), child: Text(tr('People often ask'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted2))),
                  for (final c in chips)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () => _ask(c.$2, c.$3),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: const StadiumBorder(),
                            minimumSize: const Size(44, 44),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
                          ),
                          child: Text(tr(c.$2)),
                        ),
                      ),
                    ),
                ],
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
                onPressed: () => _ask(_input.text),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(54, 54)),
                icon: const Icon(Icons.arrow_forward),
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(tr('The helper explains. It never types or changes your answers. For your loan decision, ask OLEDIPO.'),
                style: TextStyle(fontSize: 12, color: AppColors.hint)),
          ),
        ]),
      ),
    );
  }
}
