/// Application constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'AI Reader';
  static const String appVersion = '1.0.0';

  // Model Info
  static const String defaultModelName = 'gemma-3b-it-int4';
  static const String modelFileExtension = '.gguf';
  static const int defaultMaxTokens = 1024;
  static const double defaultTemperature = 0.7;

  // Model download URLs (placeholders - to be updated with actual URLs)
  static const String modelDownloadBaseUrl =
      'https://huggingface.co/google/gemma-3b-it-int4';

  // File extensions
  static const List<String> supportedPdfExtensions = ['.pdf'];
  static const List<String> supportedEpubExtensions = ['.epub'];
  static const List<String> supportedExtensions = ['.pdf', '.epub'];

  // Storage keys
  static const String keyModelDownloaded = 'model_downloaded';
  static const String keyModelPath = 'model_path';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLastOpenedFile = 'last_opened_file';
  static const String keyRecentFiles = 'recent_files';

  // Database
  static const String databaseName = 'ai_reader.db';
  static const int databaseVersion = 1;

  // UI
  static const int maxRecentFiles = 10;
  static const int summaryPreviewLength = 150;

  // Performance
  static const int defaultInferenceThreads = 4;
  static const int maxContextTokens = 8192;
}
