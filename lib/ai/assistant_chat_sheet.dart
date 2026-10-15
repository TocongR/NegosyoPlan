import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'assistant_controller.dart';
import 'gemini_service.dart';

/// The chat panel that slides up from the bottom.
class AssistantChatSheet extends StatefulWidget {
  const AssistantChatSheet({super.key});

  @override
  State<AssistantChatSheet> createState() => _AssistantChatSheetState();
}

class _AssistantChatSheetState extends State<AssistantChatSheet> {
  final _controller = AssistantController.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _defaultSuggestions = [
    'What should I input here?',
    'Explain this screen simply',
    'Check my numbers',
    'Give me a sample',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollToBottom);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty || _controller.isReplying) return;
    _input.clear();
    _controller.send(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final info = _controller.current;
            final suggestions = [
              ...?info?.suggestions,
              ..._defaultSuggestions,
            ];

            return Column(
              children: [
                // ---- header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.auto_awesome,
                            color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Negosyo Buddy',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            if (info != null)
                              Text('Helping with: ${info.screen}',
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'New chat',
                        icon: const Icon(Icons.refresh),
                        onPressed: _controller.isReplying
                            ? null
                            : _controller.clearChat,
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ---- messages
                Expanded(
                  child: _controller.messages.isEmpty
                      ? _EmptyState(screen: info?.screen)
                      : SelectionArea(
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _controller.messages.length,
                            itemBuilder: (context, i) {
                              final m = _controller.messages[i];
                              final isLast =
                                  i == _controller.messages.length - 1;
                              return _MessageBubble(
                                message: m,
                                typing: isLast &&
                                    _controller.isReplying &&
                                    m.role == ChatRole.model,
                                onUseText: m.role == ChatRole.model &&
                                        !m.isError &&
                                        !(isLast && _controller.isReplying)
                                    ? info?.onUseText
                                    : null,
                                useTextLabel: info?.useTextLabel,
                              );
                            },
                          ),
                        ),
                ),

                // ---- quick questions
                if (!_controller.isReplying)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ActionChip(
                        label: Text(suggestions[i]),
                        onPressed: () => _send(suggestions[i]),
                      ),
                    ),
                  ),

                // ---- input
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Ask anything about your negosyo…',
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          icon: _controller.isReplying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          onPressed: _controller.isReplying ? null : _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.screen});
  final String? screen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_outlined,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Hi! I\'m your Negosyo Buddy.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              screen == null
                  ? 'Ask me anything about planning your business.'
                  : 'Ask me what to input on "$screen", what a term means, '
                      'or let me check and summarize your numbers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.typing,
    this.onUseText,
    this.useTextLabel,
  });

  final ChatMessage message;
  final bool typing;
  final void Function(String text)? onUseText;
  final String? useTextLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;

    final bg = message.isError
        ? scheme.errorContainer
        : isUser
            ? scheme.primary
            : scheme.surfaceContainerHighest;
    final fg = message.isError
        ? scheme.onErrorContainer
        : isUser
            ? scheme.onPrimary
            : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: message.text.isEmpty && typing
                  ? Text('Thinking…', style: TextStyle(color: fg))
                  : isUser
                      ? Text(message.text, style: TextStyle(color: fg))
                      : SimpleMarkdown(text: message.text, color: fg),
            ),
            if (!isUser && !message.isError && !typing && message.text.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Copied')),
                      );
                    },
                  ),
                  if (onUseText != null)
                    TextButton.icon(
                      icon: const Icon(Icons.input, size: 16),
                      label: Text(useTextLabel ?? 'Use this'),
                      onPressed: () {
                        onUseText!(_plain(message.text));
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _plain(String s) => s.replaceAll('**', '').trim();
}

/// Tiny markdown renderer: # headings, **bold**, "- " bullets, "1." lists.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(color: color);
    final lines = text.trimRight().split('\n');
    final children = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      final heading = RegExp(r'^#{1,6}\s+(.*)').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+(.*)').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)').firstMatch(line);

      if (heading != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(_inline(heading.group(1)!,
              base.copyWith(fontWeight: FontWeight.bold, fontSize: 15))),
        ));
      } else if (bullet != null) {
        children.add(_listRow('•', bullet.group(1)!, base));
      } else if (numbered != null) {
        children.add(_listRow('${numbered.group(1)}.', numbered.group(2)!, base));
      } else {
        children.add(Text.rich(_inline(line, base)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _listRow(String marker, String content, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18, child: Text(marker, style: style)),
          Expanded(child: Text.rich(_inline(content, style))),
        ],
      ),
    );
  }

  TextSpan _inline(String s, TextStyle style) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold)));
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}