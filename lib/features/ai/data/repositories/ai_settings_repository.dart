import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_settings.dart';

/// Repository for managing AI settings in SharedPreferences
class AiSettingsRepository {
  AiSettingsRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'ai_settings';

  /// Load settings
  AiSettings load() {
    final json = _prefs.getString(_key);
    if (json == null) return const AiSettings();

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AiSettings.fromJson(map);
    } catch (e) {
      return const AiSettings();
    }
  }

  /// Save settings
  Future<void> save(AiSettings settings) async {
    final json = jsonEncode(settings.toJson());
    await _prefs.setString(_key, json);
  }

  /// Update language
  Future<AiSettings> updateLanguage(String language) async {
    final current = load();
    final updated = current.copyWith(language: language);
    await save(updated);
    return updated;
  }

  /// Update prompt template
  Future<AiSettings> updatePromptTemplate(String templateId) async {
    final current = load();
    final updated = current.copyWith(promptTemplateId: templateId);
    await save(updated);
    return updated;
  }

  /// Update custom prompt
  Future<AiSettings> updateCustomPrompt(String? customPrompt) async {
    final current = load();
    final updated = current.copyWith(customPromptTemplate: customPrompt);
    await save(updated);
    return updated;
  }
}
