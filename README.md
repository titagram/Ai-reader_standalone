# AI Reader

Offline PDF/EPUB reader with AI-powered summarization using Google Gemma 3B.

## Features

- **PDF & EPUB Support**: Read and navigate PDF and EPUB documents
- **AI Summarization**: Generate intelligent summaries using Gemma 3B running locally
- **Text Highlighting**: Highlight important passages with multiple colors
- **Annotations**: Add notes to highlighted text
- **Offline-First**: All processing happens locally on your device
- **Summary History**: Save and manage generated summaries

## Architecture

The app follows a modular, clean architecture pattern:

```
lib/
├── core/                  # Core utilities, theme, routing
│   ├── router/           # GoRouter configuration
│   ├── theme/            # App theme and colors
│   ├── services/         # Service locator, DI
│   ├── constants/        # App constants
│   └── utils/            # Extensions, Result type
├── features/
│   ├── home/             # Home screen with recent files
│   ├── reader/           # PDF/EPUB viewer
│   ├── summary/          # Summary display
│   ├── history/          # Summary history
│   ├── settings/         # App settings
│   ├── ai/               # AI inference module
│   ├── document/         # Document services (PDF, EPUB)
│   └── storage/          # Local database
└── main.dart
```

## AI Model

The app uses Google Gemma 3B with int4 quantization for efficient on-device inference.

### Model Requirements

- **RAM**: Minimum 8GB recommended
- **Storage**: ~2GB for the model file
- **CPU**: ARM64 with NEON support

### Integration

The native inference is handled via FFI bindings to a C++ library. To complete the integration:

1. Clone [gemma.cpp](https://github.com/google/gemma.cpp)
2. Build for Android ARM64
3. Update `CMakeLists.txt` to link against the compiled library

## Dependencies

- **State Management**: Riverpod
- **Navigation**: GoRouter
- **PDF Viewing**: Syncfusion Flutter PDF Viewer
- **EPUB Parsing**: epubx
- **Local Storage**: sqflite
- **FFI**: dart:ffi for native code integration

## Building

```bash
# Get dependencies
flutter pub get

# Generate code (freezed, riverpod_generator)
flutter pub run build_runner build

# Build APK
flutter build apk --release
```

## Configuration

### Syncfusion License

Add your Syncfusion license key in the app initialization if required for production use.

### Model Download

The AI model is downloaded on first use from Hugging Face. Ensure the device has internet connectivity for the initial download.

## Privacy

All document processing and AI inference happens locally on the device. No data is sent to external servers.

## License

This project uses open-source components:
- Google Gemma 3B: [Gemma Terms of Use](https://ai.google.dev/gemma/terms)
- Syncfusion: Community License for qualifying applications
