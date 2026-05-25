# Implementation Plan: Flutter Group @Mention Feature

## Overview

Implement the complete @mention system for the Flutter mobile app covering four flows: sending @mentions (input trigger → member picker → mentions JSON → send), receiving @mentions (WebSocket → badge → "[有人@你]" prefix), reading @mentions (navigation bar → jump to message → mark read), and rendering @mentions (highlighted @username spans in message bubbles). The backend already fully supports this feature; this plan focuses on Flutter client-side integration.

## Tasks

- [x] 1. Register MentionProvider and fix deduplication bug
  - [x] 1.1 Register MentionProvider in main.dart MultiProvider
    - Add `import '../providers/mention_provider.dart'` to `lib/main.dart`
    - Add `ChangeNotifierProvider(create: (_) => MentionProvider())` to the providers list in `MultiProvider`
    - _Requirements: Dependencies section — MentionProvider registration_

  - [x] 1.2 Fix addMention deduplication bug in MentionProvider
    - In `lib/providers/mention_provider.dart`, modify the `addMention` method to check for existing `message_id` before inserting
    - Add deduplication logic: if `mentionData['message_id']` already exists in `_unreadMentions[groupId]`, skip the insert
    - Also add `_extractTextContent` helper method for content parsing
    - _Requirements: Property 2 (Deduplication), Algorithm 4_

- [x] 2. Create MentionInputController
  - [x] 2.1 Implement MentionInputController class
    - Create `lib/utils/mention_input_controller.dart`
    - Implement `checkMentionTrigger(String text, int cursorPosition)` — detect "@" at valid word boundary (start of line, after space/newline)
    - Implement `insertMention(dynamic userId, String nickname, TextEditingController controller)` — insert "@nickname\u00A0" at cursor, add userId to pendingMentions
    - Implement `buildMentionsJson()` — serialize pendingMentions to JSON array string (ints and/or "all")
    - Implement `clearPendingMentions()` and `dispose()`
    - _Requirements: Algorithm 1 (Trigger Detection), Algorithm 2 (Mention Insertion), Property 5 (Trigger word boundary), Property 8 (Mention JSON format)_

  - [ ]* 2.2 Write unit tests for MentionInputController
    - Test `checkMentionTrigger` with: "@" at start of text, after space, after newline, mid-word (should NOT trigger), empty text, cursor at 0
    - Test `insertMention` with: cursor after "@", multiple mentions, "all" userId
    - Test `buildMentionsJson` with: empty list, single user, multiple users, "all" + users
    - _Requirements: Property 5, Property 8_

- [x] 3. Create MemberPickerSheet widget
  - [x] 3.1 Implement MemberPickerSheet bottom sheet
    - Create `lib/widgets/member_picker_sheet.dart`
    - Implement `StatefulWidget` with parameters: `groupId`, `currentUserId`, `isAdmin`, `onSelect` callback
    - Fetch group members via `GET /groups/{groupId}/members` on init
    - Display searchable list with avatars, nicknames, and role badges
    - Show "所有人" (All) option at top for admins/owners only
    - Filter out current user from the list
    - Implement search/filter TextField at top of sheet
    - Handle loading state, error state with retry button, and empty state
    - Call `onSelect(userId, nickname)` on member tap, then pop the sheet
    - _Requirements: Component 2 (MemberPickerSheet), Error Scenario 5_

  - [ ]* 3.2 Write unit tests for MemberPickerSheet
    - Test that "所有人" option only shows for admin/owner
    - Test that current user is filtered out
    - Test search filtering logic
    - _Requirements: Component 2_

- [x] 4. Create MentionRichText utility
  - [x] 4.1 Implement MentionRichText parser
    - Create `lib/utils/mention_rich_text.dart`
    - Implement static `parse` method with regex `r'@([\w\u4e00-\u9fff]{1,20})'`
    - Return `List<InlineSpan>` with highlighted @mention spans (primary color, FontWeight.w500)
    - Support `onMentionTap` callback with `TapGestureRecognizer`
    - Handle edge cases: empty content, no matches, consecutive @mentions, @ at end of string
    - Import `package:flutter/gestures.dart` for TapGestureRecognizer
    - _Requirements: Algorithm 6 (Mention Text Rendering), Component 6 (MentionRichText)_

  - [ ]* 4.2 Write unit tests for MentionRichText
    - Test parsing with Chinese names, English names, mixed content
    - Test empty string, no @mentions, multiple consecutive @mentions
    - Test that non-mention text uses baseStyle
    - _Requirements: Algorithm 6_

- [x] 5. Checkpoint - Ensure all new files compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Enhance ConversationProvider and conversation list page
  - [x] 6.1 Add clearMentionBadge and enhance totalUnread in ConversationProvider
    - In `lib/providers/conversation_provider.dart`, add `clearMentionBadge(int groupId)` method
    - This method finds the group conversation and sets `mention_unread_count` to 0, then calls `notifyListeners()`
    - Enhance `totalUnread` getter: for muted groups, only count `mention_unread_count` toward badge total (not regular unread)
    - _Requirements: Component 4 (ConversationProvider), Algorithm 3 (Badge), Property 4 (Badge visibility for muted groups)_

  - [x] 6.2 Add "[有人@你]" prefix and fix muted badge in conversation_list_page.dart
    - In `lib/pages/chat/conversation_list_page.dart`, read `mention_unread_count` from conversation data
    - Modify subtitle rendering: prepend `[有人@你] ` (red, bold) when `mentionCount > 0` for group conversations
    - Modify badge rendering: muted groups with `mentionCount > 0` show red badge (not gray dot)
    - Non-muted groups keep existing red badge with unread count
    - Muted groups with only regular unread (no mentions) keep gray dot
    - _Requirements: Algorithm 3 (Conversation Badge & Subtitle), Property 4 (Badge visibility for muted groups)_

- [x] 7. Integrate mention components into ChatPage
  - [x] 7.1 Integrate MentionInputController and MemberPickerSheet in ChatPage
    - In `lib/pages/chat/chat_page.dart`, instantiate `MentionInputController` in `_ChatPageState`
    - Add `_messageController.addListener(_onTextChanged)` in `initState`
    - Implement `_onTextChanged`: call `checkMentionTrigger` → if true, show `MemberPickerSheet` via `showModalBottomSheet`
    - In `_showMemberPicker`: pass `groupId`, `currentUserId`, `isAdmin`, and `onSelect` callback
    - In `onSelect` callback: call `_mentionController.insertMention(userId, nickname, _messageController)`
    - In `_sendMessage`: inject `_mentionController.buildMentionsJson()` into FormData, clear after success
    - Dispose `_mentionController` in `dispose()`
    - _Requirements: Component 1 (MentionInputController integration), Flow 1 (Sending @Mentions)_

  - [x] 7.2 Integrate MentionNavWidget and navigation in ChatPage
    - In `initState` (for group chats): call `mentionProvider.init()` and `fetchUnreadMentions(_groupId!)` via `addPostFrameCallback`
    - In `build()`, above the input area: add `Consumer<MentionProvider>` that renders `MentionNavWidget` when `unreadCount > 0`
    - Implement `_navigateToNextMention()`: call `mentionProvider.navigateNext(groupId)` → use `MessageNavigationHelper.scrollToMessage` → on success, call `markRead`
    - Implement `_navigateToPrevMention()`: same pattern with `navigatePrev`
    - In `_markAsRead()` (existing method): add `mentionProvider.clearAll(_groupId!)` and `conversationProvider.clearMentionBadge(_groupId!)`
    - _Requirements: Flow 3 (Reading @Mentions), Algorithm 5 (Navigation), Component 5 (MentionNavWidget integration)_

  - [x] 7.3 Integrate MentionRichText in message bubble rendering
    - In `lib/pages/chat/chat_page.dart`, locate the text message rendering section in message bubbles
    - For group chat text messages, replace plain `Text(content)` with `RichText` using `MentionRichText.parse()`
    - Apply `mentionStyle` with `AppColors.primary` and `FontWeight.w500`
    - Keep plain `Text` for non-group messages (no @mention rendering needed)
    - _Requirements: Flow 4 (Rendering @Mentions), Component 6 (MentionRichText integration)_

- [x] 8. Final checkpoint - Ensure all tests pass and integration is complete
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements from the design document for traceability
- Checkpoints ensure incremental validation
- The design uses Dart/Flutter code directly — no language translation needed
- MentionProvider and MentionNavWidget already exist; this plan focuses on integration and new components
- ChatPage is 2500+ lines — modifications should be minimal and surgical
- All backend APIs are already implemented; no server-side changes needed

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "2.1", "4.1"] },
    { "id": 1, "tasks": ["2.2", "3.1", "4.2"] },
    { "id": 2, "tasks": ["3.2", "6.1"] },
    { "id": 3, "tasks": ["6.2"] },
    { "id": 4, "tasks": ["7.1", "7.2", "7.3"] }
  ]
}
```
