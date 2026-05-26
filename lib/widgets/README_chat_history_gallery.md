# Chat History Gallery Widget

A Flutter widget that displays chat history in a gallery format with tabs for different content types (Media, Files, Links, Messages). This widget matches the design of the Vue component with the same functionality.

## Features

- **Tab Navigation**: Four tabs for different content types
  - 影音 (Media): Images and videos in a grid layout
  - 文件 (Files): Document files with download capability
  - 链接 (Links): Shared links with favicon display
  - 消息 (Messages): Text messages with search and date filtering

- **Dark Theme Support**: Automatically adapts to the app's theme
- **Responsive Design**: Works on both mobile and desktop
- **Search & Filter**: Text messages support keyword search and date range filtering
- **Lazy Loading**: Loads more content as you scroll
- **File Preview**: Integrates with existing file preview system

## Usage

### Basic Usage

```dart
import 'package:flutter/material.dart';
import '../widgets/chat_history_gallery.dart';

// Show chat history gallery
showDialog(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ChatHistoryGallery(
      friendId: 1, // or groupId for group chats
      friendName: 'Chat Partner',
      isMobile: false,
      onClose: () => Navigator.of(context).pop(),
      onFilePreview: (fileType, url, fileName, fileSize) {
        // Handle file preview
        // fileType: 'image', 'video', 'file'
        // url: file URL
        // fileName: file name
        // fileSize: file size in bytes
      },
    ),
  ),
);
```

### Parameters

- `friendId`: ID of the friend (for individual chats)
- `groupId`: ID of the group (for group chats)
- `friendName`: Display name for the chat
- `isMobile`: Whether the widget is displayed on mobile
- `onClose`: Callback when the close button is pressed
- `onFilePreview`: Callback when a file is selected for preview

### Integration with Navigation

The widget is accessible via the demo route:
```dart
Navigator.of(context).pushNamed('/demo/chat_history');
```

Or directly from the home page using the floating action button.

## Data Models

The widget uses several data models:

### MediaItem
```dart
class MediaItem {
  final String id;
  final MediaType type; // image, video, audio
  final String url;
  final String? thumbnail;
  final String fileName;
  final DateTime createdAt;
  final String? duration; // for videos
}
```

### FileItem
```dart
class FileItem {
  final String id;
  final String fileName;
  final int fileSize;
  final String url;
  final DateTime createdAt;
}
```

### LinkItem
```dart
class LinkItem {
  final String id;
  final String url;
  final String? favicon;
  final DateTime createdAt;
}
```

### TextItem
```dart
class TextItem {
  final String id;
  final String content;
  final String senderName;
  final String senderAvatar;
  final DateTime createdAt;
}
```

## Styling

The widget uses the app's theme system:
- Colors from `AppColors`
- Text styles from `AppTextStyles`
- Spacing from `AppSpacing`
- Automatically adapts to dark/light theme

## API Integration

Currently uses dummy data for demonstration. To integrate with your API:

1. Replace the dummy data generators in `_getDummyMediaItems()`, `_getDummyFileItems()`, etc.
2. Update the `_loadTabData()` method to call your actual API endpoints
3. Implement proper error handling and loading states

## Dependencies

- `cached_network_image`: For image caching and display
- `iconsax_flutter`: For modern icons
- App theme system (colors, text styles, spacing)

## Demo

A demo page is available at `/demo/chat_history` route to showcase all features of the widget.
