import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/inference_config.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/ai_model_repository.dart';
import '../ffi/gemma_ffi_bindings.dart';

/// Implementation of AI model repository using Gemma FFI bindings
class AiModelRepositoryImpl implements AiModelRepository {
  AiModelRepositoryImpl({required String modelsPath}) : _modelsPath = modelsPath;

  final String _modelsPath;
  final Dio _dio = Dio();
  CancelToken? _downloadCancelToken;
  ModelInfo? _currentModel;
  bool _isModelLoaded = false;
  Isolate? _inferenceIsolate;
  SendPort? _isolateSendPort;

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  bool get isModelReady => _isModelLoaded;

  @override
  List<ModelInfo> getAvailableModels() {
    return DefaultModels.availableModels;
  }

  @override
  Future<Result<bool>> isModelDownloaded(String modelName) async {
    try {
      final model = getAvailableModels().firstWhere(
        (m) => m.name == modelName,
        orElse: () => throw Exception('Model not found'),
      );

      final modelPath = '$_modelsPath/${model.fileName}';
      final file = File(modelPath);

      return Result.success(await file.exists());
    } catch (e) {
      return Result.failure('Failed to check model status', e);
    }
  }

  @override
  Future<Result<ModelInfo>> downloadModel(
    ModelInfo model, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Create models directory if needed
      final modelsDir = Directory(_modelsPath);
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final modelPath = '$_modelsPath/${model.fileName}';
      final file = File(modelPath);

      // Check if already downloaded
      if (await file.exists()) {
        final updatedModel = model.copyWith(
          status: ModelStatus.downloaded,
          localPath: modelPath,
          downloadProgress: 1.0,
        );
        return Result.success(updatedModel);
      }

      // Start download
      _downloadCancelToken = CancelToken();

      await _dio.download(
        model.downloadUrl,
        modelPath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress?.call(progress);
          }
        },
      );

      final updatedModel = model.copyWith(
        status: ModelStatus.downloaded,
        localPath: modelPath,
        downloadProgress: 1.0,
      );

      return Result.success(updatedModel);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return Result.failure('Download cancelled');
      }
      return Result.failure('Download failed: ${e.message}', e);
    } catch (e) {
      return Result.failure('Failed to download model', e);
    }
  }

  @override
  Future<void> cancelDownload() async {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
  }

  @override
  Future<Result<void>> loadModel(String modelPath) async {
    try {
      // Initialize FFI bindings if not already
      final ffi = GemmaFfiBindings.instance;
      if (!ffi.initialize()) {
        return Result.failure('Native inference library not available');
      }

      // Unload existing model if any
      if (_isModelLoaded) {
        await unloadModel();
      }

      // Load model in separate isolate to avoid blocking UI
      final result = await _loadModelInIsolate(modelPath);

      if (result != 0) {
        final error = ffi.getLastError();
        return Result.failure('Failed to load model: ${error ?? 'Unknown error'}');
      }

      _isModelLoaded = true;
      _currentModel = DefaultModels.gemma3bInt4.copyWith(
        status: ModelStatus.loaded,
        localPath: modelPath,
      );

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to load model', e);
    }
  }

  Future<int> _loadModelInIsolate(String modelPath) async {
    // For now, load synchronously
    // TODO: Implement proper isolate-based loading
    final ffi = GemmaFfiBindings.instance;
    return ffi.initModel(modelPath, 4);
  }

  @override
  Future<Result<void>> unloadModel() async {
    try {
      if (!_isModelLoaded) {
        return Result.success(null);
      }

      final ffi = GemmaFfiBindings.instance;
      if (ffi.isAvailable) {
        ffi.freeModel();
      }

      _isModelLoaded = false;
      _currentModel = null;

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to unload model', e);
    }
  }

  @override
  Future<Result<String>> generateText(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    if (!_isModelLoaded) {
      return Result.failure('Model not loaded');
    }

    try {
      final cfg = config ?? const InferenceConfig();
      final ffi = GemmaFfiBindings.instance;

      if (!ffi.isAvailable) {
        return Result.failure('Native inference library not available');
      }

      final result = ffi.generate(
        prompt,
        cfg.maxTokens,
        cfg.temperature,
        cfg.topK,
        cfg.topP,
      );

      if (result == null) {
        final error = ffi.getLastError();
        return Result.failure('Generation failed: ${error ?? 'Unknown error'}');
      }

      return Result.success(result);
    } catch (e) {
      return Result.failure('Failed to generate text', e);
    }
  }

  @override
  Future<Result<String>> generateSummary(
    String text, {
    String? language,
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    // Build summarization prompt
    final lang = language ?? 'the same language as the text';
    final prompt = _buildSummarizationPrompt(text, lang);

    return generateText(
      prompt,
      config: config ?? InferenceConfig.summarization,
      onToken: onToken,
    );
  }

  @override
  Future<Result<String>> generateWithCustomPrompt(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    // Wrap prompt in Gemma format
    final formattedPrompt = '''<start_of_turn>user
$prompt
<end_of_turn>
<start_of_turn>model
''';

    return generateText(
      formattedPrompt,
      config: config ?? InferenceConfig.summarization,
      onToken: onToken,
    );
  }

  String _buildSummarizationPrompt(String text, String language) {
    // Truncate text if too long
    final maxLength = 8000;
    final truncatedText =
        text.length > maxLength ? text.substring(0, maxLength) : text;

    return '''<start_of_turn>user
Please provide a comprehensive summary of the following document in $language.
Focus on the main ideas, key points, and important conclusions.
Keep the summary concise but informative.

Document:
$truncatedText
<end_of_turn>
<start_of_turn>model
''';
  }

  @override
  Future<Result<void>> deleteModel(String modelName) async {
    try {
      final model = getAvailableModels().firstWhere(
        (m) => m.name == modelName,
        orElse: () => throw Exception('Model not found'),
      );

      final modelPath = '$_modelsPath/${model.fileName}';
      final file = File(modelPath);

      if (await file.exists()) {
        await file.delete();
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete model', e);
    }
  }

  @override
  Future<String?> getLocalModelPath(String modelName) async {
    try {
      final model = getAvailableModels().firstWhere(
        (m) => m.name == modelName,
        orElse: () => throw Exception('Model not found'),
      );

      final modelPath = '$_modelsPath/${model.fileName}';
      final file = File(modelPath);

      if (await file.exists()) {
        return modelPath;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
