# Smart Image Gallery App

A Flutter application that provides an intelligent image gallery with AI-powered captioning using BLIP ONNX models.

## Features

- **Smart Captioning**: Automatically generates captions for images using BLIP vision models
- **Gallery View**: Browse local images in a responsive grid layout
- **Search**: Search images by generated captions using natural language queries
- **Favorites**: Mark images as favorites for quick access
- **Albums**: Organize images into custom albums (coming soon)
- **Secure Authentication**: Login/signup with secure local storage

## Architecture

The app follows MVVM architecture with:
- **Models**: Data classes (ImageItem, Album)
- **Services**: Business logic (MediaService, OnnxInferenceService, AuthService)
- **Repositories**: Data persistence (CaptionRepository)
- **View Models**: State management with Riverpod
- **UI**: Feature-based screen organization

## Setup

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode for platform-specific builds

## Download models

[Download Folder](https://drive.google.com/drive/folders/1I9_aOo4dpimXp-HqxvqxJj5vWZMY-bho?usp=sharing)



### Installation

1. Copy ONNX model files to `assets/models/`:
   - `blip_vision_encoder.onnx`
   - `blip_text_decoder.onnx`
   - `blip_vision_encoder.onnx.data`
   - `blip_text_decoder.onnx.data`

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code (for Riverpod and Hive):
```bash
flutter pub run build_runner build
```

4. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── image_item.dart
│   └── album.dart
├── services/
│   ├── auth_service.dart
│   ├── media_service.dart
│   └── onnx_inference_service.dart
├── repositories/
│   └── caption_repository.dart
├── view_models/
│   └── gallery_view_model.dart
└── ui/
    ├── login/
    │   └── login_screen.dart
    ├── gallery/
    │   ├── gallery_screen.dart
    │   └── image_detail_screen.dart
    ├── search/
    │   └── search_screen.dart
    ├── albums/
    │   └── albums_screen.dart
    └── settings/
        └── settings_screen.dart
```

## Permissions

### Android
- `READ_MEDIA_IMAGES` (Android 13+)
- `READ_MEDIA_VIDEO` (Android 13+)
- `READ_EXTERNAL_STORAGE` (Android 10-12)
- `ACCESS_MEDIA_LOCATION`

### iOS
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- Minimum iOS version: 16.0

## Dependencies

- **flutter_riverpod**: State management
- **photo_manager**: Access device photo library
- **onnxruntime_v2**: ONNX model inference
- **hive**: Local database for caption storage
- **flutter_secure_storage**: Secure credential storage

## Notes

- ONNX models are loaded from assets at runtime
- Captions are cached locally to avoid re-processing
- Image processing runs in background isolates to keep UI responsive
- The app uses lazy loading for thumbnails to optimize memory usage

## Future Enhancements

- Complete albums feature
- Image sharing with captions
- Multilingual caption support
- Cloud sync for captions and favorites
- Export captions to CSV/JSON

