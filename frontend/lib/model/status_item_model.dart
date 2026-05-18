class StatusItemModel {
  const StatusItemModel({
    required this.id,
    required this.content,
    required this.type,
    required this.userId,

    this.url,
  });

  final String? id;
  final String? content;
  final String? type;
  final String? url;
  final String? userId;

  factory StatusItemModel.fromMap(Map<String, dynamic> map) {
    return StatusItemModel(
      id: '${map['id']}',
      content: '${map['content'] ?? ''}',
      type: '${map['type'] ?? 'text'}',
      url: map['url']?.toString(),
      userId: '${map['userId']}',
    );
  }
}
