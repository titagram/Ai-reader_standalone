/// AI settings for summary generation
class AiSettings {
  const AiSettings({
    this.language = 'it',
    this.promptTemplateId = 'detailed',
    this.customPromptTemplate,
  });

  final String language;
  final String promptTemplateId;
  final String? customPromptTemplate;

  /// Get display name for language
  String get languageDisplayName {
    switch (language) {
      case 'it':
        return 'Italiano';
      case 'en':
        return 'English';
      default:
        return language;
    }
  }

  /// Get the active prompt template
  String get activePromptTemplate {
    if (promptTemplateId == 'custom' && customPromptTemplate != null) {
      return customPromptTemplate!;
    }
    return PromptTemplates.templates[promptTemplateId] ??
           PromptTemplates.templates['detailed']!;
  }

  /// Build the final prompt with variables replaced
  String buildPrompt({
    required String text,
    required String unitType,
    required int unitNumber,
  }) {
    final langName = language == 'it' ? 'italiano' : 'English';

    return activePromptTemplate
        .replaceAll('{{text}}', text)
        .replaceAll('{{language}}', langName)
        .replaceAll('{{unit_type}}', unitType)
        .replaceAll('{{unit_number}}', unitNumber.toString());
  }

  AiSettings copyWith({
    String? language,
    String? promptTemplateId,
    String? customPromptTemplate,
  }) {
    return AiSettings(
      language: language ?? this.language,
      promptTemplateId: promptTemplateId ?? this.promptTemplateId,
      customPromptTemplate: customPromptTemplate ?? this.customPromptTemplate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'promptTemplateId': promptTemplateId,
      'customPromptTemplate': customPromptTemplate,
    };
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      language: json['language'] as String? ?? 'it',
      promptTemplateId: json['promptTemplateId'] as String? ?? 'detailed',
      customPromptTemplate: json['customPromptTemplate'] as String?,
    );
  }
}

/// Available languages
class SupportedLanguages {
  static const List<LanguageOption> options = [
    LanguageOption(code: 'it', name: 'Italiano'),
    LanguageOption(code: 'en', name: 'English'),
  ];
}

class LanguageOption {
  const LanguageOption({required this.code, required this.name});
  final String code;
  final String name;
}

/// Predefined prompt templates
class PromptTemplates {
  static const Map<String, String> templates = {
    'concise': '''Riassumi brevemente in 2-3 frasi il contenuto di questa {{unit_type}} in {{language}}.
Sii conciso e vai dritto al punto.

Testo:
{{text}}''',

    'detailed': '''Spiega in modo chiaro e didattico il contenuto di questa {{unit_type}} in {{language}}.
Evidenzia i concetti chiave, fornisci contesto dove necessario, e usa un tono educativo
che aiuti a comprendere anche argomenti complessi.

Testo:
{{text}}''',

    'keypoints': '''Elenca i punti principali di questa {{unit_type}} in {{language}}.
Usa un formato a bullet point, con massimo 5-7 punti.
Ogni punto deve essere una frase completa e autosufficiente.

Testo:
{{text}}''',
  };

  static const List<TemplateOption> options = [
    TemplateOption(
      id: 'concise',
      name: 'Riassunto conciso',
      description: 'Breve riassunto in 2-3 frasi',
    ),
    TemplateOption(
      id: 'detailed',
      name: 'Spiegazione dettagliata',
      description: 'Spiegazione didattica con concetti chiave',
    ),
    TemplateOption(
      id: 'keypoints',
      name: 'Punti chiave',
      description: 'Lista di 5-7 punti principali',
    ),
    TemplateOption(
      id: 'custom',
      name: 'Personalizzato',
      description: 'Template personalizzato',
    ),
  ];
}

class TemplateOption {
  const TemplateOption({
    required this.id,
    required this.name,
    required this.description,
  });
  final String id;
  final String name;
  final String description;
}
