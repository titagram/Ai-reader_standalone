import 'package:ai_reader/core/utils/result.dart';
import 'package:ai_reader/features/ai/domain/entities/inference_config.dart';
import 'package:ai_reader/features/ai/domain/entities/model_info.dart';
import 'package:ai_reader/features/ai/domain/repositories/ai_model_repository.dart';

/// A mock implementation of [AiModelRepository] for unit testing.
///
/// Configurable flags control whether operations succeed or fail.
/// Call counts track how many times each method was invoked.
class MockAiModelRepository implements AiModelRepository {
  // --------------- Configuration flags ---------------

  bool shouldFailDownload = false;
  bool shouldFailLoad = false;
  bool shouldFailGenerate = false;
  bool shouldReportNotDownloaded = true;

  /// The string returned by [generateText] and [generateSummary] on success.
  String generateResult = 'Mock summary of the provided text.';

  // --------------- Call counters ---------------

  int isModelDownloadedCallCount = 0;
  int downloadModelCallCount = 0;
  int cancelDownloadCallCount = 0;
  int loadModelCallCount = 0;
  int unloadModelCallCount = 0;
  int generateTextCallCount = 0;
  int generateSummaryCallCount = 0;
  int generateWithCustomPromptCallCount = 0;
  int deleteModelCallCount = 0;
  int getLocalModelPathCallCount = 0;

  // --------------- Internal state ---------------

  ModelInfo? _currentModel;
  bool _isModelReady = false;

  // --------------- AiModelRepository implementation ---------------

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  bool get isModelReady => _isModelReady;

  @override
  List<ModelInfo> getAvailableModels() {
    return DefaultModels.availableModels;
  }

  @override
  Future<Result<bool>> isModelDownloaded(String modelName) async {
    isModelDownloadedCallCount++;
    return Result.success(!shouldReportNotDownloaded);
  }

  @override
  Future<Result<ModelInfo>> downloadModel(
    ModelInfo model, {
    DownloadProgressCallback? onProgress,
  }) async {
    downloadModelCallCount++;

    if (shouldFailDownload) {
      return Result.failure('Download failed', Exception('Mock download error'));
    }

    // Simulate progress callbacks
    onProgress?.call(0.25);
    onProgress?.call(0.50);
    onProgress?.call(0.75);
    onProgress?.call(1.0);

    final downloaded = model.copyWith(
      status: ModelStatus.downloaded,
      downloadProgress: 1.0,
      localPath: '/mock/path/${model.fileName}',
    );
    _currentModel = downloaded;
    return Result.success(downloaded);
  }

  @override
  Future<void> cancelDownload() async {
    cancelDownloadCallCount++;
  }

  @override
  Future<Result<void>> loadModel(String modelPath) async {
    loadModelCallCount++;

    if (shouldFailLoad) {
      return Result.failure('Load failed', Exception('Mock load error'));
    }

    _isModelReady = true;
    return Result.success(null);
  }

  @override
  Future<Result<void>> unloadModel() async {
    unloadModelCallCount++;
    _isModelReady = false;
    return Result.success(null);
  }

  @override
  Future<Result<String>> generateText(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    generateTextCallCount++;

    if (shouldFailGenerate) {
      return Result.failure(
          'Generation failed', Exception('Mock generation error'));
    }

    return Result.success(generateResult);
  }

  @override
  Future<Result<String>> generateSummary(
    String text, {
    String? language,
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    generateSummaryCallCount++;

    if (shouldFailGenerate) {
      return Result.failure(
          'Generation failed', Exception('Mock generation error'));
    }

    return Result.success(generateResult);
  }

  @override
  Future<Result<String>> generateWithCustomPrompt(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    generateWithCustomPromptCallCount++;

    if (shouldFailGenerate) {
      return Result.failure(
          'Generation failed', Exception('Mock generation error'));
    }

    return Result.success(generateResult);
  }

  @override
  Future<Result<void>> deleteModel(String modelName) async {
    deleteModelCallCount++;
    return Result.success(null);
  }

  @override
  Future<String?> getLocalModelPath(String modelName) async {
    getLocalModelPathCallCount++;
    if (shouldReportNotDownloaded) {
      return null;
    }
    return '/mock/path/$modelName.gguf';
  }
}
