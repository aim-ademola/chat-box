import 'package:backend/models/chat_message.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class Conversation extends Model<Conversation> {
  Conversation() : super(() => Conversation());

  String get userId => getAttribute('userId')?.toString() ?? '';
  String get friendId => getAttribute('friendId')?.toString() ?? '';
  String get lastMessageId => getAttribute('lastMessageId')?.toString() ?? '';
  String get lastSenderId => getAttribute('lastSenderId')?.toString() ?? '';
  String get type => getAttribute('type')?.toString() ?? 'direct';
  String get title => getAttribute('title')?.toString() ?? '';
  String get profilePicUrl => getAttribute('profilePicUrl')?.toString() ?? '';
  String get memberIds => getAttribute('memberIds')?.toString() ?? '';
  String get createdBy => getAttribute('createdBy')?.toString() ?? '';

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
            name: 'type',
            type: ColumnType.string,
            length: 32,
            defaultValue: 'direct',
          ),
          Column(name: 'title', type: ColumnType.string, isNullable: true),
          Column(
            name: 'profilePicUrl',
            type: ColumnType.string,
            isNullable: true,
          ),
          Column(name: 'memberIds', type: ColumnType.text, isNullable: true),
          Column(name: 'createdBy', type: ColumnType.string, isNullable: true),
          Column(
              name: 'lastMessageId', type: ColumnType.string, isNullable: true),
          Column(
              name: 'lastSenderId', type: ColumnType.string, isNullable: true),
        ],
      );
}
