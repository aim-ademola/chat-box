import 'dart:isolate';

import 'package:flint_dart/schema.dart';
import 'package:backend/models/chat_message.dart';
import 'package:backend/models/user_model.dart';

import 'package:backend/models/status.dart';
import 'package:backend/models/status_read.dart';

import 'package:backend/models/conversation.dart';

void main(_, SendPort? sendPort) {
  runTableRegistry([
    User().table,
    ChatMessage().table,
    Status().table,
    StatusRead().table,
    Conversation().table,
  ], _, sendPort);
}
