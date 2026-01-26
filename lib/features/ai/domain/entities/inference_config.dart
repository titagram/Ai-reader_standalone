import 'package:equatable/equatable.dart';

/// Configuration for AI inference
class InferenceConfig extends Equatable {
  const InferenceConfig({
    this.maxTokens = 1024,
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.95,
    this.repeatPenalty = 1.1,
    this.threads = 4,
  });

  /// Maximum number of tokens to generate
  final int maxTokens;

  /// Temperature for sampling (0.0 - 1.0)
  final double temperature;

  /// Top-K sampling parameter
  final int topK;

  /// Top-P (nucleus) sampling parameter
  final double topP;

  /// Penalty for repeating tokens
  final double repeatPenalty;

  /// Number of threads for inference
  final int threads;

  /// Create a copy with updated values
  InferenceConfig copyWith({
    int? maxTokens,
    double? temperature,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? threads,
  }) {
    return InferenceConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      threads: threads ?? this.threads,
    );
  }

  /// Default configuration for summarization
  static const InferenceConfig summarization = InferenceConfig(
    maxTokens: 512,
    temperature: 0.5,
    topK: 40,
    topP: 0.9,
    repeatPenalty: 1.2,
    threads: 4,
  );

  /// Default configuration for creative tasks
  static const InferenceConfig creative = InferenceConfig(
    maxTokens: 1024,
    temperature: 0.8,
    topK: 50,
    topP: 0.95,
    repeatPenalty: 1.1,
    threads: 4,
  );

  @override
  List<Object?> get props => [
        maxTokens,
        temperature,
        topK,
        topP,
        repeatPenalty,
        threads,
      ];
}
