import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_locator.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../domain/entities/ai_settings.dart';

/// Provider for AI settings repository
final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return AiSettingsRepository(ServiceLocator.instance.preferences);
});

/// Notifier for AI settings
class AiSettingsNotifier extends StateNotifier<AiSettings> {
  AiSettingsNotifier(this._repository) : super(_repository.load());

  final AiSettingsRepository _repository;

  /// Update language
  Future<void> setLanguage(String language) async {
    state = await _repository.updateLanguage(language);
  }

  /// Update prompt template
  Future<void> setPromptTemplate(String templateId) async {
    state = await _repository.updatePromptTemplate(templateId);
  }

  /// Update custom prompt
  Future<void> setCustomPrompt(String? customPrompt) async {
    state = await _repository.updateCustomPrompt(customPrompt);
  }

  /// Reset to defaults
  Future<void> reset() async {
    state = const AiSettings();
    await _repository.save(state);
  }
}

/// Provider for AI settings state
final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  final repository = ref.watch(aiSettingsRepositoryProvider);
  return AiSettingsNotifier(repository);
});
