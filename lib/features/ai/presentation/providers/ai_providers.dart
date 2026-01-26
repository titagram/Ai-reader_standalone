import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_locator.dart';
import '../../domain/entities/inference_config.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/ai_model_repository.dart';

/// Provider for AI model repository
final aiModelRepositoryProvider = Provider<AiModelRepository>((ref) {
  return ServiceLocator.instance.createAiModelRepository();
});

/// State for model management
class ModelState {
  const ModelState({
    this.currentModel,
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.error,
  });

  final ModelInfo? currentModel;
  final bool isLoading;
  final bool isDownloading;
  final double downloadProgress;
  final String? error;

  bool get isReady =>
      currentModel != null && currentModel!.status == ModelStatus.loaded;

  ModelState copyWith({
    ModelInfo? currentModel,
    bool? isLoading,
    bool? isDownloading,
    double? downloadProgress,
    String? error,
  }) {
    return ModelState(
      currentModel: currentModel ?? this.currentModel,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error,
    );
  }
}

/// Notifier for managing AI model state
class ModelStateNotifier extends StateNotifier<ModelState> {
  ModelStateNotifier(this._repository) : super(const ModelState());

  final AiModelRepository _repository;

  /// Check and update model status
  Future<void> checkModelStatus() async {
    final model = DefaultModels.gemma3bInt4;
    final result = await _repository.isModelDownloaded(model.name);

    result.fold(
      onSuccess: (isDownloaded) {
        if (isDownloaded) {
          state = state.copyWith(
            currentModel: model.copyWith(status: ModelStatus.downloaded),
          );
        } else {
          state = state.copyWith(
            currentModel: model.copyWith(status: ModelStatus.notDownloaded),
          );
        }
      },
      onFailure: (message, error) {
        state = state.copyWith(error: message);
      },
    );
  }

  /// Download model
  Future<void> downloadModel() async {
    final model = state.currentModel ?? DefaultModels.gemma3bInt4;

    state = state.copyWith(
      isDownloading: true,
      downloadProgress: 0.0,
      currentModel: model.copyWith(status: ModelStatus.downloading),
    );

    final result = await _repository.downloadModel(
      model,
      onProgress: (progress) {
        state = state.copyWith(downloadProgress: progress);
      },
    );

    result.fold(
      onSuccess: (updatedModel) {
        state = state.copyWith(
          isDownloading: false,
          downloadProgress: 1.0,
          currentModel: updatedModel,
        );
      },
      onFailure: (message, error) {
        state = state.copyWith(
          isDownloading: false,
          error: message,
          currentModel: model.copyWith(
            status: ModelStatus.error,
            error: message,
          ),
        );
      },
    );
  }

  /// Cancel download
  Future<void> cancelDownload() async {
    await _repository.cancelDownload();
    state = state.copyWith(
      isDownloading: false,
      downloadProgress: 0.0,
      currentModel: state.currentModel?.copyWith(
        status: ModelStatus.notDownloaded,
      ),
    );
  }

  /// Load model for inference
  Future<void> loadModel() async {
    final model = state.currentModel;
    if (model == null || !model.isDownloaded) {
      state = state.copyWith(error: 'Model not downloaded');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      currentModel: model.copyWith(status: ModelStatus.loading),
    );

    final modelPath = await _repository.getLocalModelPath(model.name);
    if (modelPath == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Model file not found',
      );
      return;
    }

    final result = await _repository.loadModel(modelPath);

    result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          isLoading: false,
          currentModel: model.copyWith(status: ModelStatus.loaded),
        );
      },
      onFailure: (message, error) {
        state = state.copyWith(
          isLoading: false,
          error: message,
          currentModel: model.copyWith(
            status: ModelStatus.error,
            error: message,
          ),
        );
      },
    );
  }

  /// Unload model
  Future<void> unloadModel() async {
    await _repository.unloadModel();
    state = state.copyWith(
      currentModel: state.currentModel?.copyWith(
        status: ModelStatus.downloaded,
      ),
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for model state
final modelStateProvider =
    StateNotifierProvider<ModelStateNotifier, ModelState>((ref) {
  final repository = ref.watch(aiModelRepositoryProvider);
  return ModelStateNotifier(repository);
});

/// State for summarization
class SummarizationState {
  const SummarizationState({
    this.isGenerating = false,
    this.summary,
    this.error,
    this.progress = 0.0,
  });

  final bool isGenerating;
  final String? summary;
  final String? error;
  final double progress;

  SummarizationState copyWith({
    bool? isGenerating,
    String? summary,
    String? error,
    double? progress,
  }) {
    return SummarizationState(
      isGenerating: isGenerating ?? this.isGenerating,
      summary: summary ?? this.summary,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// Notifier for summarization
class SummarizationNotifier extends StateNotifier<SummarizationState> {
  SummarizationNotifier(this._repository) : super(const SummarizationState());

  final AiModelRepository _repository;

  /// Generate summary from text
  Future<void> generateSummary(
    String text, {
    String? language,
    InferenceConfig? config,
  }) async {
    state = state.copyWith(
      isGenerating: true,
      summary: null,
      error: null,
      progress: 0.0,
    );

    final result = await _repository.generateSummary(
      text,
      language: language,
      config: config,
    );

    result.fold(
      onSuccess: (summary) {
        state = state.copyWith(
          isGenerating: false,
          summary: summary,
          progress: 1.0,
        );
      },
      onFailure: (message, error) {
        state = state.copyWith(
          isGenerating: false,
          error: message,
        );
      },
    );
  }

  /// Clear state
  void clear() {
    state = const SummarizationState();
  }
}

/// Provider for summarization state
final summarizationProvider =
    StateNotifierProvider<SummarizationNotifier, SummarizationState>((ref) {
  final repository = ref.watch(aiModelRepositoryProvider);
  return SummarizationNotifier(repository);
});
