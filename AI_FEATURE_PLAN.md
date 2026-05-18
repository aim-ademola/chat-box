# AI Feature Plan

## Goal

Add an AI assistant layer to ChatBox that can:

- Summarize chat conversations.
- Summarize calls after call data/transcripts exist.
- Detect important messages the user has not replied to.
- Detect possible meetings, follow-ups, dates, and deadlines from chats and calls.
- Show the user a useful "AI digest" with reminders and next meeting suggestions.

## Current Codebase Snapshot

The app is split into:

- `backend/`: Dart + FlintDart API server on port `3001`.
- `frontend/`: Flutter app using `flint_client`, Riverpod, and secure storage.

Useful existing backend pieces:

- `ChatController` already supports:
  - `GET /chat/recent`
  - `GET /chat/rooms/:roomId/messages`
  - websocket chat send/receive through `/chat/rooms/:roomId`
- `ChatMessage` stores:
  - `conversationId`
  - `senderId`
  - `recipientId`
  - `content`
  - `messageType`
  - `sentAt`
- `Conversation` stores:
  - `userId`
  - `friendId`
  - `lastMessageId`
  - `lastSenderId`

Useful existing frontend pieces:

- `ChatRepositry` already fetches recent chats, room history, and creates chat sockets.
- `RecentChatsNotifier` maps backend recent chats into `MessageItemModel`.
- `ChatDetailScreen` displays chat history and websocket messages.
- `CallScreen` is currently only a placeholder, so call AI features need call storage first.

## Important Gaps Before AI

1. There is no call model, call route, call repository, call history screen, transcript field, or call recording integration yet.
2. Messages do not currently track read/unread state, reply status, or whether a message has been dismissed from reminders.
3. There is no AI service abstraction in the backend.
4. There is no database table for AI summaries, AI extracted tasks, reminders, or meeting suggestions.
5. There is no backend environment/config pattern visible yet for secrets such as an AI provider API key.

## Recommended Architecture

Keep AI on the backend, not directly in Flutter.

Reasons:

- API keys stay private.
- Summaries can be cached in the database.
- The backend can combine chat, call, user, and reminder data safely.
- The frontend only needs normal authenticated API calls.

Suggested backend modules:

- `lib/services/ai_service.dart`
  - Owns provider calls.
  - Accepts normalized text/messages.
  - Returns structured Dart objects/maps.
- `lib/controllers/ai_controller.dart`
  - Exposes authenticated AI endpoints.
- `lib/routes/ai_routes.dart`
  - Mounts AI endpoints under `/ai`.
- `lib/models/ai_summary.dart`
  - Stores cached summaries for conversations and calls.
- `lib/models/ai_reminder.dart`
  - Stores messages/tasks the user should reply to or remember.
- `lib/models/meeting_suggestion.dart`
  - Stores possible meetings extracted from messages/calls.

Suggested frontend modules:

- `lib/repositry/ai_repositry.dart`
  - Calls backend AI endpoints.
- `lib/provider/ai_digest_provider.dart`
  - Loads the user's digest/reminders.
- `lib/model/ai_digest_model.dart`
  - Represents summaries, reminders, and meeting suggestions.
- UI entry points:
  - Add an AI digest card/section to `HomeScreen`.
  - Add "Summarize" and "Important" controls inside `ChatDetailScreen`.
  - Add AI summary area to `CallScreen` after calls exist.

## Backend API Plan

### Phase 1: Chat AI

Add endpoints:

- `GET /ai/chats/:conversationId/summary`
  - Returns a cached summary when available.
  - Can refresh when query param `?refresh=true` is passed.
- `GET /ai/chats/:conversationId/actions`
  - Returns extracted reply reminders, tasks, deadlines, and meeting suggestions for one chat.
- `GET /ai/digest`
  - Returns all important reminders and upcoming meeting suggestions for the signed-in user.

Input data:

- Pull last 100-300 messages from `ChatMessage`.
- Include sender names where possible.
- Filter to conversations where the authenticated user is a participant.

Output shape:

```json
{
  "status": true,
  "data": {
    "summary": "Short readable summary",
    "openQuestions": [],
    "replyReminders": [],
    "meetingSuggestions": [],
    "generatedAt": "2026-05-18T00:00:00.000Z"
  }
}
```

### Phase 2: Reminder Tracking

Add durable reminder models:

- `ai_reminders`
  - `userId`
  - `conversationId`
  - `messageId`
  - `title`
  - `reason`
  - `priority`
  - `status`: `open`, `done`, `dismissed`
  - `dueAt`
  - `createdAt`

Add endpoints:

- `GET /ai/reminders`
- `PATCH /ai/reminders/:id`
  - Mark as done or dismissed.

Detection rules:

- A reminder should usually be created when another user asks a direct question, asks for confirmation, sends a deadline, or asks the current user to do something.
- Do not remind about messages sent by the current user.
- Avoid duplicate reminders for the same message.

### Phase 3: Meeting Suggestions

Add durable meeting suggestion model:

- `meeting_suggestions`
  - `userId`
  - `sourceType`: `chat` or `call`
  - `sourceId`: conversation id or call id
  - `title`
  - `participants`
  - `proposedStartAt`
  - `proposedEndAt`
  - `location`
  - `confidence`
  - `status`: `suggested`, `accepted`, `dismissed`

Add endpoints:

- `GET /ai/meetings/suggestions`
- `PATCH /ai/meetings/suggestions/:id`

Later optional integration:

- Export accepted meeting to device calendar.
- Add Google/Outlook calendar sync if needed.

### Phase 4: Call AI

Before call summaries can work, add call data:

- `Call` model:
  - `callerId`
  - `recipientId`
  - `startedAt`
  - `endedAt`
  - `status`
  - `callType`: `audio` or `video`
  - `transcript`
  - `recordingUrl`
- `CallRoutes`
- `CallController`
- `CallRepositry`
- A real `CallScreen` list/history UI.

Then add:

- `GET /ai/calls/:callId/summary`
- `GET /ai/calls/:callId/actions`

Call summarization depends on transcripts. If the app will record audio, the backend also needs a transcription step before summarization.

## Data Privacy And Safety

- Do not send full user objects to the AI provider; send only necessary display names and message text.
- Enforce auth checks before every AI endpoint.
- Confirm the signed-in user belongs to the conversation/call before summarizing.
- Cache summaries so the same chat is not repeatedly sent to the AI provider.
- Add a visible generated timestamp in the UI.
- Let users dismiss reminders and meeting suggestions.

## Suggested Prompt Contract

Ask the AI service to return strict JSON with:

- `summary`: short paragraph or bullets.
- `importantMessages`: messages that need attention.
- `replyReminders`: direct questions or requests awaiting the current user's response.
- `tasks`: action items with owner and due date when known.
- `meetingSuggestions`: possible meetings with date/time, participants, and confidence.

The backend should validate and normalize the JSON before storing it.

## Frontend UX Plan

### Home / Digest

Add an "AI Digest" section that shows:

- Top 3 reply reminders.
- Next meeting suggestion.
- A button to open all AI reminders.

### Recent Chats

Optionally add a small indicator when a chat has:

- An unanswered message.
- A pending meeting suggestion.
- A fresh summary.

### Chat Detail

Add a compact AI panel near the top of the chat:

- "Summarize"
- "Need reply"
- "Possible meeting"

The panel should be collapsible so it does not interrupt normal chatting.

### Calls

After calls are implemented:

- Show call summary.
- Show extracted decisions and next steps.
- Show possible next meeting.

## Implementation Order

1. Create backend AI route/controller/service skeleton.
2. Add `AiSummary`, `AiReminder`, and `MeetingSuggestion` models and register tables.
3. Add chat summary endpoint using existing `ChatMessage` data.
4. Add chat action extraction endpoint.
5. Add frontend AI repository/provider/models.
6. Add AI summary panel to `ChatDetailScreen`.
7. Add AI digest section to the home screen.
8. Add reminder done/dismiss actions.
9. Add call model/routes/UI.
10. Add call transcript and call summary support.

## First Safe Build Slice

The first implementation should be small:

- Backend:
  - Add `/ai/chats/:conversationId/summary`.
  - Pull existing chat messages.
  - Return a basic generated summary response.
  - Keep the AI provider behind `AiService`.
- Frontend:
  - Add `AiRepositry`.
  - Add one "Summarize" button in `ChatDetailScreen`.
  - Show loading, summary text, and error states.

This gets a working AI chat summary without needing the call system or reminder database first.

## Call API Decision

Use Agora first for in-app voice/video calls.

Why Agora fits this app:

- The app is already a Flutter chat app, so calls should feel like app-to-app calling.
- Agora has Flutter SDK support for real-time audio/video.
- The backend can create secure call channels and issue tokens.
- The call model can stay owned by our backend, while Agora handles the live media.
- Transcription can be added through Agora recording/transcription or through recorded audio sent to a separate transcription service.

Do not use Twilio as the first choice unless the product needs real phone number calling. Twilio is stronger for PSTN/phone calls, call centers, IVR, and SIP-style workflows.

Daily is a good alternative if the product should feel more like meeting rooms with built-in transcription, but Agora is a better first fit for WhatsApp-style chat + call behavior.

## Chosen Implementation Plan For This App

The app should be built in layers so each feature works before the next one depends on it.

### Layer 1: AI For Existing Chats

This layer uses the chat data already stored in `chat_messages`.

Backend files to add:

- `backend/lib/services/ai_service.dart`
- `backend/lib/controllers/ai_controller.dart`
- `backend/lib/routes/ai_routes.dart`
- `backend/lib/models/ai_summary.dart`
- `backend/lib/models/ai_reminder.dart`
- `backend/lib/models/meeting_suggestion.dart`

Backend files to update:

- `backend/lib/routes/app_routes.dart`
  - Register `AiRoutes`.
- `backend/lib/config/table_registry.dart`
  - Register new AI tables.
- `backend/pubspec.yaml`
  - Add an HTTP client package if needed for AI provider calls.

Endpoints to add:

- `GET /ai/chats/:conversationId/summary`
- `GET /ai/chats/:conversationId/actions`
- `GET /ai/digest`
- `GET /ai/reminders`
- `PATCH /ai/reminders/:id`
- `GET /ai/meetings/suggestions`
- `PATCH /ai/meetings/suggestions/:id`

Frontend files to add:

- `frontend/lib/repositry/ai_repositry.dart`
- `frontend/lib/provider/ai_digest_provider.dart`
- `frontend/lib/model/ai_summary_model.dart`
- `frontend/lib/model/ai_reminder_model.dart`
- `frontend/lib/model/meeting_suggestion_model.dart`

Frontend files to update:

- `frontend/lib/screens/home/chat_detail.dart`
  - Add a compact AI summary/action panel.
- `frontend/lib/screens/home/home_screen.dart`
  - Add AI digest preview.
- `frontend/lib/screens/home/message.dart`
  - Optionally show reminder indicators beside recent chats.

### Layer 2: Call Foundation

Before call summaries can work, the app needs real call records.

Backend files to add:

- `backend/lib/models/call.dart`
- `backend/lib/controllers/call_controller.dart`
- `backend/lib/routes/call_routes.dart`
- `backend/lib/services/agora_token_service.dart`

Backend files to update:

- `backend/lib/routes/app_routes.dart`
  - Register `CallRoutes`.
- `backend/lib/config/table_registry.dart`
  - Register `Call().table`.
- `backend/pubspec.yaml`
  - Add packages needed for Agora token generation, or implement token signing if no package is available.

Call model fields:

- `id`
- `channelName`
- `callerId`
- `recipientId`
- `callType`: `audio` or `video`
- `status`: `ringing`, `accepted`, `missed`, `ended`, `failed`
- `startedAt`
- `acceptedAt`
- `endedAt`
- `durationSeconds`
- `recordingUrl`
- `transcript`
- `createdAt`

Call endpoints:

- `POST /calls`
  - Create call record and Agora channel.
  - Return call id, channel name, token, and recipient data.
- `POST /calls/:id/accept`
  - Mark call accepted and return Agora token.
- `POST /calls/:id/end`
  - Mark call ended and save duration.
- `GET /calls/recent`
  - Return call history for signed-in user.
- `GET /calls/:id`
  - Return one call record.

Websocket events:

- `call:incoming`
- `call:accepted`
- `call:ended`
- `call:missed`

These can reuse the existing user-room pattern from `ChatController`, for example `user:<userId>`.

Frontend files to add:

- `frontend/lib/repositry/call_repositry.dart`
- `frontend/lib/provider/call_provider.dart`
- `frontend/lib/model/call_model.dart`
- `frontend/lib/screens/home/call_screen.dart`
- `frontend/lib/screens/home/incoming_call_screen.dart`
- `frontend/lib/screens/home/active_call_screen.dart`

Frontend files to update:

- `frontend/lib/screens/home/chat_detail.dart`
  - Make audio/video icons start a call.
- `frontend/lib/screens/home/call.dart`
  - Replace placeholder with real call history.
- `frontend/pubspec.yaml`
  - Add Agora Flutter SDK package.

### Layer 3: Call Transcript

There are two workable transcript paths.

Recommended first path:

- Use call recording.
- Store recording URL on the `Call` row.
- Send the recording to a transcription provider.
- Save final transcript in `calls.transcript`.
- Run AI summary/action extraction on the saved transcript.

Alternative path:

- Use a live transcription provider.
- Stream partial transcript while the call is happening.
- Save final transcript at call end.

Start with post-call transcription because it is easier to build and debug.

Transcript backend files to add:

- `backend/lib/services/transcription_service.dart`
- `backend/lib/controllers/call_transcript_controller.dart` if transcript callbacks need their own endpoint.

Transcript endpoints:

- `POST /calls/:id/transcript`
  - Save transcript manually or from provider callback.
- `POST /calls/:id/transcribe`
  - Start transcription from recording URL.
- `GET /calls/:id/transcript`
  - Return transcript if available.

### Layer 4: AI For Calls

Once `calls.transcript` exists, call AI becomes similar to chat AI.

Endpoints to add:

- `GET /ai/calls/:callId/summary`
- `GET /ai/calls/:callId/actions`

Call AI output:

- Short call summary.
- Decisions made.
- Questions still open.
- Tasks and owners.
- Reply reminders.
- Next meeting suggestions.

Frontend updates:

- Show call summary on call details.
- Show "View transcript" if transcript exists.
- Add extracted reminders to the AI digest.
- Add meeting suggestions from calls to the same meeting suggestion list used by chats.

## AI Provider Implementation

Keep the AI provider replaceable.

`AiService` should expose methods like:

- `summarizeChat(...)`
- `extractChatActions(...)`
- `summarizeCall(...)`
- `extractCallActions(...)`

The controller should not know which provider is used. It should only call `AiService`.

Environment variables to support:

- `AI_PROVIDER`
- `AI_API_KEY`
- `AI_MODEL`
- `TRANSCRIPTION_PROVIDER`
- `TRANSCRIPTION_API_KEY`
- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`

The backend should fail gracefully when keys are missing:

- In development, return a clear configuration error.
- In production, return a safe generic error to the frontend.

## Detailed Build Order

1. Add chat summary endpoint with a temporary non-AI fallback summary.
2. Add real `AiService` provider call.
3. Add frontend summarize button in chat detail.
4. Add AI reminder and meeting suggestion database tables.
5. Add chat action extraction endpoint.
6. Add AI digest endpoint and home UI preview.
7. Add reminder done/dismiss actions.
8. Add Agora call model/routes/token service.
9. Add Flutter call repository and call UI screens.
10. Wire chat audio/video buttons to create calls.
11. Add call history screen.
12. Add call recording/transcript storage.
13. Add call summary and call action extraction.
14. Merge chat and call reminders into one digest.
15. Add tests for auth checks, conversation ownership checks, and AI JSON parsing.

## Implementation Notes

- Start with on-demand AI generation from buttons. Add automatic background generation later.
- Cache summaries in `ai_summaries` to avoid paying for repeated AI calls.
- Store reminders and meeting suggestions so users can dismiss them.
- Always check that the signed-in user owns the conversation or call before sending content to AI.
- Keep the Flutter UI simple first: summary panel, digest preview, reminder list.
- Add provider callbacks for transcription only after the basic call flow works.
- Do not send passwords, tokens, or full user profile data to the AI provider.

## Questions To Decide Before Full Implementation

- Which AI provider should the backend use?
- Should summaries be generated on demand, automatically after new messages, or both?
- Should reminders be private per user, or shared inside a conversation?
- Do calls already exist somewhere outside this repo, or should call history be built from scratch?
- Should meeting suggestions integrate with a calendar now, or only be shown inside ChatBox first?
