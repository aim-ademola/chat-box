import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/conversation.dart';
import 'package:backend/models/status.dart';
import 'package:backend/models/status_read.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/storage.dart';

class StatusController {
  Future<Response?> index(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;
    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }
    final summaries = [];

    final userCon = await Conversation().where("userId", user.id).get();
    final friendCon = await Conversation().where("friendId", user.id).get();
    final conversations = [...userCon, ...friendCon];
    print(conversations);
    // final conversations = await Conversation()
    //     .where("userId", user.id)
    //     .orWhere("friendId", user.id)
    //     .all();
    // print("Status :$conversations");

    for (var conversation in conversations) {
      print(conversation);
      final peerId = conversation.userId == user.id
          ? conversation.friendId
          : conversation.userId;

      print(peerId);
      final peer =
          await User().where("id", peerId).withRelation("statuses").first();
      // peer?.load("statuses");
      print(peer?.toMap());
      // final lastMessageId = conversation.lastMessageId.trim();
      // final latestMessage = lastMessageId.isEmpty
      //     ? null
      //     : await ChatMessage().find(lastMessageId);

      // if (latestMessage == null) {
      //   continue;
      // }

      // summaries.add(
      //   _RecentChatSummary(
      //     conversationId: conversation.id,
      //     peer: {
      //       'id': peer?.id.toString(),
      //       'name': peer?.name,
      //       'bio': peer?.bio,
      //       'profilePicUrl': peer?.profilePicUrl,
      //     },
      //     lastMessage: {
      //       'id': latestMessage.id?.toString(),
      //       'conversationId': latestMessage.conversationId,
      //       'senderId': latestMessage.senderId,
      //       'recipientId': latestMessage.recipientId,
      //       'content': latestMessage.content,
      //       'messageType': latestMessage.messageType,
      //       'sentAt': latestMessage.sentAt,
      //     },
      //     sentAt: _sentAtValue(latestMessage),
      //   ),
      // );

      if (peer == null ||
          peer.toMap()["statuses"] == null ||
          (peer.toMap()["statuses"] as List).isEmpty) {
        continue;
      }

      summaries.add(peer);
    }

    return res.json({
      'status': true,
      "data": summaries.map((status) => status.toMap()).toList(),
    });
  }

  Future<Response?> create(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final hasUpload = await ctx.req.hasFile('file');
    String? url;
    if (hasUpload) {
      final file = await ctx.req.file('file');
      if (file != null) {
        url = await Storage.create(file, subdirectory: 'status');
      }
    }

    final Map<String, dynamic> createForm = hasUpload
        ? Map<String, dynamic>.from(await ctx.req.form())
        : await ctx.req.json();

    print(createForm);
    final content = (createForm['content'] ?? '').toString().trim();
    final type = (createForm['type'] ?? 'text').toString().trim();

    final status = await Status().create({
      "content": content,
      'type': type.isEmpty ? 'text' : type,
      'url': url,
      "userId": user.id,
    });

    if (status != null) {
      final createdStatus = await Status().withRelation('user').find(status.id);
      return res.json({'status': true, "data": createdStatus?.toMap()});
    } else {
      return res.json({'status': false, "message": "Status could not create"});
    }
  }

  Future<Response?> getByUser(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final userId = await ctx.req.param('userId');
    if (userId == null) {
      return res
          .status(400)
          .json({'status': false, 'message': 'User id is required'});
    }

    final statuses =
        await Status().where('userId', userId).withRelation('user').all();
    return res.json({
      'status': true,
      'data': statuses.map((status) => status.toMap()).toList(),
    });
  }

  Future<Response?> readStatus(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final statusId = await ctx.req.param("id");
    final user = await ctx.req.authUser;
    if (statusId == null || user == null) {
      return res
          .status(400)
          .json({'status': false, 'message': 'Invalid status read request'});
    }

    final statusRead = await StatusRead().firstOrCreate(
      where: {"statusId": statusId, "userId": user.id},
      values: {'statusId': statusId, "userId": user.id},
    );

    return res.json({
      'status': true,
      'message': 'Status read successfully',
      "data": statusRead?.toMap(),
    });
  }

  Future<Response?> getReadStatus(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final statusId = await ctx.req.param('id');
    final statusReads = await StatusRead().where("statusId", statusId).get();
    return res.json({
      'status': true,
      "data": statusReads.map((statusRead) => statusRead.toMap()).toList(),
    });
  }
}
