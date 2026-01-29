import 'package:equatable/equatable.dart';

/// Model status enumeration
enum ModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  loading,
  loaded,
  error,
}

/// Information about an AI model
class ModelInfo extends Equatable {
  const ModelInfo({
    required this.name,
    required this.displayName,
    required this.description,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.fileName,
    this.version = '1.0',
    this.quantization = 'int4',
    this.parameters = '3B',
    this.contextLength = 8192,
    this.status = ModelStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.localPath,
    this.error,
  });

  final String name;
  final String displayName;
  final String description;
  final String downloadUrl;
  final int fileSizeBytes;
  final String fileName;
  final String version;
  final String quantization;
  final String parameters;
  final int contextLength;
  final ModelStatus status;
  final double downloadProgress;
  final String? localPath;
  final String? error;

  /// Get file size in human readable format
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Check if model is ready for inference
  bool get isReady => status == ModelStatus.loaded;

  /// Check if model is available locally
  bool get isDownloaded =>
      status == ModelStatus.downloaded ||
      status == ModelStatus.loading ||
      status == ModelStatus.loaded;

  /// Create copy with updated values
  ModelInfo copyWith({
    String? name,
    String? displayName,
    String? description,
    String? downloadUrl,
    int? fileSizeBytes,
    String? fileName,
    String? version,
    String? quantization,
    String? parameters,
    int? contextLength,
    ModelStatus? status,
    double? downloadProgress,
    String? localPath,
    String? error,
  }) {
    return ModelInfo(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileName: fileName ?? this.fileName,
      version: version ?? this.version,
      quantization: quantization ?? this.quantization,
      parameters: parameters ?? this.parameters,
      contextLength: contextLength ?? this.contextLength,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        name,
        displayName,
        description,
        downloadUrl,
        fileSizeBytes,
        fileName,
        version,
        quantization,
        parameters,
        contextLength,
        status,
        downloadProgress,
        localPath,
        error,
      ];
}

/// Default Gemma model configurations
class DefaultModels {
  DefaultModels._();

  static const ModelInfo gemma3bInt4 = ModelInfo(
    name: 'gemma-3-1b-it-q4km',
    displayName: 'Gemma 3 1B IT (Q4_K_M)',
    description:
        'Google Gemma 3 1B instruction-tuned model, Q4_K_M quantized for efficient mobile inference. ~769 MB download.',
    downloadUrl:
        'https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
    fileSizeBytes: 806058272, // ~769 MB
    fileName: 'gemma-3-1b-it-Q4_K_M.gguf',
    version: '3.0',
    quantization: 'Q4_K_M',
    parameters: '1B',
    contextLength: 8192,
  );

  static List<ModelInfo> get availableModels => [gemma3bInt4];
}
