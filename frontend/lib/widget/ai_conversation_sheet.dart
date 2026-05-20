import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/app_theme_colors.dart';
import 'package:frontend/model/ai_chat_turn_model.dart';
import 'package:frontend/model/ai_summary_model.dart';
import 'package:frontend/repositry/ai_repositry.dart';

class AiConversationSheet extends ConsumerStatefulWidget {
  const AiConversationSheet({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.initialSummary,
    required this.onSummaryLoaded,
  });

  final String conversationId;
  final String contactName;
  final AiSummaryModel? initialSummary;
  final ValueChanged<AiSummaryModel> onSummaryLoaded;

  @override
  ConsumerState<AiConversationSheet> createState() =>
      _AiConversationSheetState();
}

class _AiConversationSheetState extends ConsumerState<AiConversationSheet> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatTurnModel> _turns = [];

  AiSummaryModel? _summary;
  bool _loadingSummary = true;
  bool _asking = false;
  String? _error;
  String _provider = 'gemini';

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    _loadingSummary = widget.initialSummary == null;
    _loadSummary();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary =
          _summary ??
          await ref
              .read(aiRepositryProvider)
              .getChatSummary(
                conversationId: widget.conversationId,
                provider: _provider,
              );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadingSummary = false;
        _error = null;
      });
      widget.onSummaryLoaded(summary);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _error = 'Could not load AI summary.';
      });
    }
  }

  Future<void> _askQuestion([String? preset]) async {
    final question = (preset ?? _questionController.text).trim();
    if (question.isEmpty || _asking) {
      return;
    }

    _questionController.clear();
    setState(() {
      _asking = true;
      _error = null;
      _turns.add(
        AiChatTurnModel(
          text: question,
          isUser: true,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    try {
      final answer = await ref
          .read(aiRepositryProvider)
          .askChat(
            conversationId: widget.conversationId,
            question: question,
            provider: _provider,
          );
      if (!mounted) return;
      setState(() {
        _turns.add(
          AiChatTurnModel(
            text: answer,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        );
        _asking = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _error = 'Could not answer that question right now.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildSummary(ColorScheme colorScheme, AppThemeColors palette) {
    if (_loadingSummary) {
      return Container(
        height: 112,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    final summary = _summary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Conversation brief',
                style: AppStyle.circularTextStyle(
                  size: 16,
                  weight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.summary,
            style: AppStyle.circularTextStyle(
              size: 14,
              weight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                colorScheme,
                '${summary.messageCount} messages',
                Icons.chat_bubble_outline_rounded,
              ),
              if (summary.openQuestions.isNotEmpty)
                _buildMetricChip(
                  colorScheme,
                  '${summary.openQuestions.length} need reply',
                  Icons.mark_chat_unread_outlined,
                ),
              if (summary.meetingSuggestions.isNotEmpty)
                _buildMetricChip(
                  colorScheme,
                  '${summary.meetingSuggestions.length} meetings',
                  Icons.event_available_outlined,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppStyle.circularTextStyle(
                size: 13,
                weight: FontWeight.w600,
                color: palette.offline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(ColorScheme colorScheme, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppStyle.circularTextStyle(
              size: 12,
              weight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons(ColorScheme colorScheme) {
    final prompts = [
      'What should I reply to?',
      'Any important messages?',
      'Is there a meeting here?',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final prompt in prompts) ...[
            ActionChip(
              onPressed: _asking ? null : () => _askQuestion(prompt),
              avatar: Icon(
                Icons.bolt_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              label: Text(prompt),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSwitch(ColorScheme colorScheme) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'gemini', label: Text('Gemini')),
        ButtonSegment(value: 'openai', label: Text('OpenAI')),
        ButtonSegment(value: 'local', label: Text('Local')),
      ],
      selected: {_provider},
      showSelectedIcon: false,
      onSelectionChanged: _asking || _loadingSummary
          ? null
          : (values) {
              final nextProvider = values.first;
              setState(() {
                _provider = nextProvider;
                _summary = null;
                _loadingSummary = true;
                _error = null;
              });
              _loadSummary();
            },
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: AppStyle.circularTextStyle(
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTurn(AiChatTurnModel turn, ColorScheme colorScheme) {
    final alignment = turn.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleColor = turn.isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final textColor = turn.isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          turn.text,
          style: AppStyle.circularTextStyle(
            size: 14,
            weight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ColorScheme colorScheme, AppThemeColors palette) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        0,
        12,
        0,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _questionController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _askQuestion(),
                decoration: InputDecoration(
                  hintText: 'Ask about this conversation',
                  hintStyle: AppStyle.circularTextStyle(
                    size: 14,
                    weight: FontWeight.w500,
                    color: palette.secondaryText,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _asking ? null : _askQuestion,
            icon: _asking
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          children: [
            _buildHandle(colorScheme),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask AI',
                        style: AppStyle.circularTextStyle(
                          size: 24,
                          weight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.contactName,
                        style: AppStyle.circularTextStyle(
                          size: 14,
                          weight: FontWeight.w600,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildProviderSwitch(colorScheme),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  _buildSummary(colorScheme, palette),
                  const SizedBox(height: 14),
                  _buildPresetButtons(colorScheme),
                  const SizedBox(height: 18),
                  for (final turn in _turns) _buildTurn(turn, colorScheme),
                ],
              ),
            ),
            _buildComposer(colorScheme, palette),
          ],
        ),
      ),
    );
  }
}
