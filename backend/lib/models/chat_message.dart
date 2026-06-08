import 'package:backend/models/conversation.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class ChatMessage extends Model<ChatMessage> {
  ChatMessage() : super(() => ChatMessage());

  String? get conversationId => getAttribute('conversationId');
  String? get senderId => getAttribute('senderId');
  String? get recipientId => getAttribute('recipientId');
  String? get content => getAttribute('content');
  String? get messageType => getAttribute('messageType');
  String? get sentAt => getAttribute('sentAt');
  String? get readAt => getAttribute('readAt');
  String? get expiresAt => getAttribute('expiresAt');
  User? get sender => getRelation<User>('sender');

  @override
  Map<String, RelationDefinition> get relations => {
        'sender': Relations.belongsTo(
          'sender',
          () => User(),
          foreignKey: 'senderId',
          ownerKey: 'id',
        ),
        "conversation": Relations.belongsTo<Conversation>(
          "conversation",
          () => Conversation(),
          foreignKey: "conversationId",
          ownerKey: "id",
        )
      };

  @override
  Table get table => Table(
        name: 'chat_messages',
        columns: [
          Column(name: 'conversationId', type: ColumnType.string, length: 255),
          Column(name: 'senderId', type: ColumnType.string, length: 255),
          Column(
            name: 'recipientId',
            type: ColumnType.string,
            length: 255,
            isNullable: true,
          ),
          Column(
            name: 'content',
            type: ColumnType.text,
          ),
          Column(
            name: 'messageType',
            type: ColumnType.string,
            length: 32,
            defaultValue: 'text',
          ),
          Column(
            name: 'sentAt',
            type: ColumnType.string,
            length: 64,
            defaultValue: '',
          ),
          Column(
            name: 'readAt',
            type: ColumnType.string,
            length: 64,
            defaultValue: '',
          ),
          Column(
            name: 'expiresAt',
            type: ColumnType.string,
            length: 64,
            defaultValue: '',
          ),
        ],
      );
}
