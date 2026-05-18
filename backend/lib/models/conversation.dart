import 'package:backend/models/chat_message.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class Conversation extends Model<Conversation> {
  Conversation() : super(() => Conversation());

  String get userId => getAttribute('userId');
  String get friendId => getAttribute('friendId');
  String get lastMessageId => getAttribute('lastMessageId');
  String get lastSenderId => getAttribute('lastSenderId');

  Map<String, RelationDefinition> get relations => {
        'user': Relations.belongsTo<User>(
          'user',
          () => User(),
          foreignKey: 'userId',
          ownerKey: 'id',
        ),
        'friend': Relations.belongsTo<User>(
          'friend',
          () => User(),
          foreignKey: 'friendId',
          ownerKey: 'id',
        ),
        'chatMessages':
            Relations.hasMany<ChatMessage>("messages", () => ChatMessage()),
        "lastMessage": Relations.hasOne(
          "lastMessage",
          () => ChatMessage(),
          foreignKey: "lastMessageId",
        ),
        'lastSender': Relations.belongsTo<User>(
          'lastSender',
          () => User(),
          foreignKey: 'lastSenderId',
          ownerKey: 'id',
        ),
      };

  @override
  Table get table => Table(
        name: 'conversations',
        columns: [
          Column(name: 'userId', type: ColumnType.string),
          Column(name: 'friendId', type: ColumnType.string),
          Column(
              name: 'lastMessageId', type: ColumnType.string, isNullable: true),
          Column(
              name: 'lastSenderId', type: ColumnType.string, isNullable: true),
        ],
      );
}
