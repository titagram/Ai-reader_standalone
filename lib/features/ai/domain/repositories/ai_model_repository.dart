import '../../../../core/utils/result.dart';
import '../entities/inference_config.dart';
import '../entities/model_info.dart';

/// Callback for download progress updates
typedef DownloadProgressCallback = void Function(double progress);

/// Callback for inference token generation
typedef TokenCallback = void Function(String token);

/// Repository interface for AI model operations
abstract class AiModelRepository {
  /// Get current model info
  ModelInfo? get currentModel;

  /// Check if model is loaded and ready
  bool get isModelReady;

  /// Get list of available models
  List<ModelInfo> getAvailableModels();

  /// Check if model is downloaded locally
  Future<Result<bool>> isModelDownloaded(String modelName);

  /// Download model from URL
  Future<Result<ModelInfo>> downloadModel(
    ModelInfo model, {
    DownloadProgressCallback? onProgress,
  });

  /// Cancel ongoing download
  Future<void> cancelDownload();

  /// Load model into memory for inference
  Future<Result<void>> loadModel(String modelPath);

  /// Unload model from memory
  Future<Result<void>> unloadModel();

  /// Generate text from prompt
  Future<Result<String>> generateText(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  });

  /// Generate summary of text
  Future<Result<String>> generateSummary(
    String text, {
    String? language,
    InferenceConfig? config,
    TokenCallback? onToken,
  });

  /// Delete downloaded model
  Future<Result<void>> deleteModel(String modelName);

  /// Get local model path if downloaded
  Future<String?> getLocalModelPath(String modelName);
}
