class AiChatTurnModel {
  const AiChatTurnModel({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  final String text;
  final bool isUser;
  final DateTime createdAt;
}
