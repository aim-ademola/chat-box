class AiSummaryModel {
  const AiSummaryModel({
    required this.conversationId,
    required this.summary,
    required this.messageCount,
    required this.generatedAt,
    required this.source,
    this.openQuestions = const [],
    this.importantMessages = const [],
    this.meetingSuggestions = const [],
  });

  final String conversationId;
  final String summary;
  final int messageCount;
  final String generatedAt;
  final String source;
  final List<Map<String, dynamic>> openQuestions;
  final List<Map<String, dynamic>> importantMessages;
  final List<Map<String, dynamic>> meetingSuggestions;

  factory AiSummaryModel.fromMap(Map<String, dynamic> map) {
    return AiSummaryModel(
      conversationId: map['conversationId']?.toString() ?? '',
      summary: map['summary']?.toString() ?? 'No summary available yet.',
      messageCount: int.tryParse(map['messageCount']?.toString() ?? '') ?? 0,
      generatedAt: map['generatedAt']?.toString() ?? '',
      source: map['source']?.toString() ?? 'local',
      openQuestions: _mapList(map['openQuestions']),
      importantMessages: _mapList(map['importantMessages']),
      meetingSuggestions: _mapList(map['meetingSuggestions']),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
