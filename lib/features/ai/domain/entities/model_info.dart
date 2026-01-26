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

/// Default Gemma 3B model configuration
class DefaultModels {
  DefaultModels._();

  static const ModelInfo gemma3bInt4 = ModelInfo(
    name: 'gemma-3b-it-int4',
    displayName: 'Gemma 3B IT (int4)',
    description:
        'Google Gemma 3B instruction-tuned model, quantized to 4-bit for efficient mobile inference.',
    downloadUrl:
        'https://huggingface.co/google/gemma-3-3b-it-qat-q4_0-gguf/resolve/main/gemma-3-3b-it-q4_0.gguf',
    fileSizeBytes: 2000000000, // ~2GB
    fileName: 'gemma-3-3b-it-q4_0.gguf',
    version: '3.0',
    quantization: 'int4',
    parameters: '3B',
    contextLength: 8192,
  );

  static List<ModelInfo> get availableModels => [gemma3bInt4];
}
