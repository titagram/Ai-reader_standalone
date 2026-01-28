# Page-by-Page Summaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement on-demand page/chapter summaries with persistence, visual overlays, language selection, and customizable prompts.

**Architecture:** New `page_summaries` table for persistence, `AiSettings` entity for configuration stored in SharedPreferences, overlay widgets on PDF pages and EPUB chapters, and a bottom sheet for displaying/managing summaries.

**Tech Stack:** Flutter, Riverpod, SQLite (sqflite), SharedPreferences, Syncfusion PDF Viewer, epubx

---

## Task 1: Database Migration - Add `page_summaries` Table

**Files:**
- Modify: `lib/features/storage/data/datasources/database_helper.dart`
- Modify: `lib/core/constants/app_constants.dart`

**Step 1: Update database version**

In `lib/core/constants/app_constants.dart`, change line 33:

```dart
static const int databaseVersion = 2;
```

**Step 2: Add new table creation and migration**

In `lib/features/storage/data/datasources/database_helper.dart`, add after line 96 (inside `_onCreate`):

```dart
    // Create page_summaries table
    await db.execute('''
      CREATE TABLE page_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path TEXT NOT NULL,
        unit_number INTEGER NOT NULL,
        unit_type TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        prompt_template_id TEXT,
        language TEXT DEFAULT 'it',
        created_at TEXT NOT NULL,
        UNIQUE(document_path, unit_number, unit_type)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_page_summaries_doc ON page_summaries(document_path)');
```

**Step 3: Add migration logic in `_onUpgrade`**

Replace lines 99-104 with:

```dart
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration to version 2: add page_summaries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS page_summaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_path TEXT NOT NULL,
          unit_number INTEGER NOT NULL,
          unit_type TEXT NOT NULL,
          summary_text TEXT NOT NULL,
          prompt_template_id TEXT,
          language TEXT DEFAULT 'it',
          created_at TEXT NOT NULL,
          UNIQUE(document_path, unit_number, unit_type)
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_page_summaries_doc ON page_summaries(document_path)');
    }
  }
```

**Step 4: Commit**

```bash
git add lib/features/storage/data/datasources/database_helper.dart lib/core/constants/app_constants.dart
git commit -m "feat(db): add page_summaries table with migration to v2"
```

---

## Task 2: Create `PageSummary` Entity

**Files:**
- Create: `lib/features/ai/domain/entities/page_summary.dart`

**Step 1: Create the entity file**

```dart
/// Represents a summary for a specific page (PDF) or chapter (EPUB)
class PageSummary {
  const PageSummary({
    this.id,
    required this.documentPath,
    required this.unitNumber,
    required this.unitType,
    required this.summaryText,
    this.promptTemplateId,
    required this.language,
    required this.createdAt,
  });

  final int? id;
  final String documentPath;
  final int unitNumber;
  final UnitType unitType;
  final String summaryText;
  final String? promptTemplateId;
  final String language;
  final DateTime createdAt;

  /// Create from database map
  factory PageSummary.fromMap(Map<String, dynamic> map) {
    return PageSummary(
      id: map['id'] as int?,
      documentPath: map['document_path'] as String,
      unitNumber: map['unit_number'] as int,
      unitType: UnitType.fromString(map['unit_type'] as String),
      summaryText: map['summary_text'] as String,
      promptTemplateId: map['prompt_template_id'] as String?,
      language: map['language'] as String? ?? 'it',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_path': documentPath,
      'unit_number': unitNumber,
      'unit_type': unitType.name,
      'summary_text': summaryText,
      'prompt_template_id': promptTemplateId,
      'language': language,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PageSummary copyWith({
    int? id,
    String? documentPath,
    int? unitNumber,
    UnitType? unitType,
    String? summaryText,
    String? promptTemplateId,
    String? language,
    DateTime? createdAt,
  }) {
    return PageSummary(
      id: id ?? this.id,
      documentPath: documentPath ?? this.documentPath,
      unitNumber: unitNumber ?? this.unitNumber,
      unitType: unitType ?? this.unitType,
      summaryText: summaryText ?? this.summaryText,
      promptTemplateId: promptTemplateId ?? this.promptTemplateId,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Type of content unit (page for PDF, chapter for EPUB)
enum UnitType {
  page,
  chapter;

  static UnitType fromString(String value) {
    return UnitType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UnitType.page,
    );
  }

  String get displayName {
    switch (this) {
      case UnitType.page:
        return 'pagina';
      case UnitType.chapter:
        return 'capitolo';
    }
  }

  String get displayNameEn {
    switch (this) {
      case UnitType.page:
        return 'page';
      case UnitType.chapter:
        return 'chapter';
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/ai/domain/entities/page_summary.dart
git commit -m "feat(entities): add PageSummary entity with UnitType enum"
```

---

## Task 3: Create `AiSettings` Entity and Prompt Templates

**Files:**
- Create: `lib/features/ai/domain/entities/ai_settings.dart`

**Step 1: Create the settings entity with prompt templates**

```dart
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
```

**Step 2: Commit**

```bash
git add lib/features/ai/domain/entities/ai_settings.dart
git commit -m "feat(entities): add AiSettings entity with prompt templates"
```

---

## Task 4: Create `PageSummariesRepository`

**Files:**
- Create: `lib/features/ai/data/repositories/page_summaries_repository.dart`

**Step 1: Create the repository**

```dart
import 'package:sqflite/sqflite.dart';

import '../../../storage/data/datasources/database_helper.dart';
import '../../domain/entities/page_summary.dart';

/// Repository for managing page summaries in the database
class PageSummariesRepository {
  PageSummariesRepository();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Get all summaries for a document
  Future<Map<int, PageSummary>> getSummariesForDocument(String documentPath) async {
    final db = await _db;
    final results = await db.query(
      'page_summaries',
      where: 'document_path = ?',
      whereArgs: [documentPath],
    );

    final map = <int, PageSummary>{};
    for (final row in results) {
      final summary = PageSummary.fromMap(row);
      map[summary.unitNumber] = summary;
    }
    return map;
  }

  /// Get a specific summary
  Future<PageSummary?> getSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final db = await _db;
    final results = await db.query(
      'page_summaries',
      where: 'document_path = ? AND unit_number = ? AND unit_type = ?',
      whereArgs: [documentPath, unitNumber, unitType.name],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return PageSummary.fromMap(results.first);
  }

  /// Save or update a summary
  Future<PageSummary> saveSummary(PageSummary summary) async {
    final db = await _db;

    // Check if exists
    final existing = await getSummary(
      documentPath: summary.documentPath,
      unitNumber: summary.unitNumber,
      unitType: summary.unitType,
    );

    if (existing != null) {
      // Update
      await db.update(
        'page_summaries',
        summary.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return summary.copyWith(id: existing.id);
    } else {
      // Insert
      final id = await db.insert('page_summaries', summary.toMap());
      return summary.copyWith(id: id);
    }
  }

  /// Delete a summary
  Future<void> deleteSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final db = await _db;
    await db.delete(
      'page_summaries',
      where: 'document_path = ? AND unit_number = ? AND unit_type = ?',
      whereArgs: [documentPath, unitNumber, unitType.name],
    );
  }

  /// Delete all summaries for a document
  Future<void> deleteAllForDocument(String documentPath) async {
    final db = await _db;
    await db.delete(
      'page_summaries',
      where: 'document_path = ?',
      whereArgs: [documentPath],
    );
  }

  /// Delete all summaries
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('page_summaries');
  }

  /// Check if a summary exists
  Future<bool> hasSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final summary = await getSummary(
      documentPath: documentPath,
      unitNumber: unitNumber,
      unitType: unitType,
    );
    return summary != null;
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/ai/data/repositories/page_summaries_repository.dart
git commit -m "feat(repo): add PageSummariesRepository for database operations"
```

---

## Task 5: Create `AiSettingsRepository`

**Files:**
- Create: `lib/features/ai/data/repositories/ai_settings_repository.dart`

**Step 1: Create the repository**

```dart
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
```

**Step 2: Commit**

```bash
git add lib/features/ai/data/repositories/ai_settings_repository.dart
git commit -m "feat(repo): add AiSettingsRepository for SharedPreferences storage"
```

---

## Task 6: Create AI Settings and Page Summaries Providers

**Files:**
- Create: `lib/features/ai/presentation/providers/ai_settings_provider.dart`
- Create: `lib/features/ai/presentation/providers/page_summaries_provider.dart`

**Step 1: Create AI settings provider**

Create `lib/features/ai/presentation/providers/ai_settings_provider.dart`:

```dart
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
```

**Step 2: Create page summaries provider**

Create `lib/features/ai/presentation/providers/page_summaries_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/page_summaries_repository.dart';
import '../../domain/entities/page_summary.dart';

/// Provider for page summaries repository
final pageSummariesRepositoryProvider = Provider<PageSummariesRepository>((ref) {
  return PageSummariesRepository();
});

/// State for page summary generation
class PageSummaryGenerationState {
  const PageSummaryGenerationState({
    this.isGenerating = false,
    this.generatingUnitNumber,
    this.error,
  });

  final bool isGenerating;
  final int? generatingUnitNumber;
  final String? error;

  PageSummaryGenerationState copyWith({
    bool? isGenerating,
    int? generatingUnitNumber,
    String? error,
  }) {
    return PageSummaryGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatingUnitNumber: generatingUnitNumber,
      error: error,
    );
  }
}

/// Provider for generation state
final pageSummaryGenerationStateProvider =
    StateProvider<PageSummaryGenerationState>(
        (ref) => const PageSummaryGenerationState());

/// Provider for summaries of a specific document (cached)
final documentSummariesProvider =
    FutureProvider.family<Map<int, PageSummary>, String>((ref, documentPath) async {
  final repository = ref.watch(pageSummariesRepositoryProvider);
  return repository.getSummariesForDocument(documentPath);
});

/// Provider to check if a specific unit has a summary
final hasPageSummaryProvider =
    Provider.family<bool, ({String documentPath, int unitNumber})>((ref, params) {
  final summariesAsync = ref.watch(documentSummariesProvider(params.documentPath));
  return summariesAsync.maybeWhen(
    data: (summaries) => summaries.containsKey(params.unitNumber),
    orElse: () => false,
  );
});

/// Provider to get a specific summary
final pageSummaryProvider =
    Provider.family<PageSummary?, ({String documentPath, int unitNumber})>((ref, params) {
  final summariesAsync = ref.watch(documentSummariesProvider(params.documentPath));
  return summariesAsync.maybeWhen(
    data: (summaries) => summaries[params.unitNumber],
    orElse: () => null,
  );
});
```

**Step 3: Commit**

```bash
git add lib/features/ai/presentation/providers/ai_settings_provider.dart lib/features/ai/presentation/providers/page_summaries_provider.dart
git commit -m "feat(providers): add AiSettings and PageSummaries providers"
```

---

## Task 7: Update AI Model Repository to Support Custom Prompts

**Files:**
- Modify: `lib/features/ai/data/repositories/ai_model_repository_impl.dart`
- Modify: `lib/features/ai/domain/repositories/ai_model_repository.dart`

**Step 1: Add `generateWithCustomPrompt` method to the interface**

In `lib/features/ai/domain/repositories/ai_model_repository.dart`, add after `generateSummary`:

```dart
  /// Generate text with a custom prompt (for page summaries)
  Future<Result<String>> generateWithCustomPrompt(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  });
```

**Step 2: Implement in repository**

In `lib/features/ai/data/repositories/ai_model_repository_impl.dart`, add after `generateSummary` method (line 231):

```dart
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
```

**Step 3: Commit**

```bash
git add lib/features/ai/domain/repositories/ai_model_repository.dart lib/features/ai/data/repositories/ai_model_repository_impl.dart
git commit -m "feat(ai): add generateWithCustomPrompt for custom page summaries"
```

---

## Task 8: Create SummaryBottomSheet Widget

**Files:**
- Create: `lib/features/ai/presentation/widgets/summary_bottom_sheet.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/page_summary.dart';

/// Bottom sheet for displaying and managing a page/chapter summary
class SummaryBottomSheet extends StatelessWidget {
  const SummaryBottomSheet({
    super.key,
    required this.summary,
    required this.onRegenerate,
    required this.onDelete,
  });

  final PageSummary summary;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unitLabel = summary.unitType == UnitType.page ? 'Pagina' : 'Capitolo';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  summary.unitType == UnitType.page
                      ? Icons.description
                      : Icons.book,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '$unitLabel ${summary.unitNumber}',
                  style: context.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                summary.summaryText,
                style: context.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onRegenerate();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rigenera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: summary.summaryText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copiato negli appunti')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Elimina',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina riassunto'),
        content: const Text(
          'Sei sicuro di voler eliminare questo riassunto? Dovrai rigenerarlo se ti serve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

/// Show the summary bottom sheet
Future<void> showSummaryBottomSheet({
  required BuildContext context,
  required PageSummary summary,
  required VoidCallback onRegenerate,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SummaryBottomSheet(
      summary: summary,
      onRegenerate: onRegenerate,
      onDelete: onDelete,
    ),
  );
}
```

**Step 2: Commit**

```bash
git add lib/features/ai/presentation/widgets/summary_bottom_sheet.dart
git commit -m "feat(ui): add SummaryBottomSheet for displaying page summaries"
```

---

## Task 9: Create PageSummaryOverlay Widget for PDF

**Files:**
- Create: `lib/features/ai/presentation/widgets/page_summary_overlay.dart`

**Step 1: Create the overlay widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../document/data/services/document_service_factory.dart';
import '../../data/repositories/page_summaries_repository.dart';
import '../../domain/entities/ai_settings.dart';
import '../../domain/entities/page_summary.dart';
import '../../domain/repositories/ai_model_repository.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/page_summaries_provider.dart';
import 'summary_bottom_sheet.dart';

/// Overlay icon for page summary (positioned on PDF pages)
class PageSummaryOverlay extends ConsumerStatefulWidget {
  const PageSummaryOverlay({
    super.key,
    required this.documentPath,
    required this.currentPage,
    required this.totalPages,
  });

  final String documentPath;
  final int currentPage;
  final int totalPages;

  @override
  ConsumerState<PageSummaryOverlay> createState() => _PageSummaryOverlayState();
}

class _PageSummaryOverlayState extends ConsumerState<PageSummaryOverlay> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final hasSummary = ref.watch(hasPageSummaryProvider((
      documentPath: widget.documentPath,
      unitNumber: widget.currentPage,
    )));

    final modelState = ref.watch(modelStateProvider);

    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.currentPage}/${widget.totalPages}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          // Summary button
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: _getButtonColor(hasSummary),
            child: InkWell(
              onTap: _isGenerating || !modelState.isReady
                  ? null
                  : () => _handleTap(hasSummary),
              onLongPress: hasSummary ? () => _showOptions() : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: _buildIcon(hasSummary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor(bool hasSummary) {
    if (_isGenerating) return Colors.orange;
    if (hasSummary) return AppColors.success;
    return Colors.grey.shade600;
  }

  Widget _buildIcon(bool hasSummary) {
    if (_isGenerating) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }
    return Icon(
      hasSummary ? Icons.auto_awesome : Icons.auto_awesome_outlined,
      color: Colors.white,
      size: 24,
    );
  }

  Future<void> _handleTap(bool hasSummary) async {
    if (hasSummary) {
      _showSummary();
    } else {
      await _generateSummary();
    }
  }

  void _showSummary() {
    final summary = ref.read(pageSummaryProvider((
      documentPath: widget.documentPath,
      unitNumber: widget.currentPage,
    )));

    if (summary == null) return;

    showSummaryBottomSheet(
      context: context,
      summary: summary,
      onRegenerate: () => _generateSummary(regenerate: true),
      onDelete: _deleteSummary,
    );
  }

  Future<void> _generateSummary({bool regenerate = false}) async {
    final modelState = ref.read(modelStateProvider);
    if (!modelState.isReady) {
      _showModelNotReadyDialog();
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Extract text for current page
      final service = DocumentServiceFactory.getServiceForFile(widget.documentPath);
      final textResult = await service.extractTextFromPages(
        widget.documentPath,
        widget.currentPage,
        widget.currentPage,
      );

      if (!mounted) return;

      await textResult.fold(
        onSuccess: (text) async {
          if (text.isEmpty) {
            _showError('Nessun testo trovato in questa pagina');
            return;
          }

          // Get settings and build prompt
          final settings = ref.read(aiSettingsProvider);
          final unitType = UnitType.page;
          final prompt = settings.buildPrompt(
            text: text,
            unitType: settings.language == 'it'
                ? unitType.displayName
                : unitType.displayNameEn,
            unitNumber: widget.currentPage,
          );

          // Generate summary
          final repository = ref.read(aiModelRepositoryProvider);
          final result = await repository.generateWithCustomPrompt(prompt);

          if (!mounted) return;

          await result.fold(
            onSuccess: (summaryText) async {
              // Save to database
              final pageSummary = PageSummary(
                documentPath: widget.documentPath,
                unitNumber: widget.currentPage,
                unitType: unitType,
                summaryText: summaryText,
                promptTemplateId: settings.promptTemplateId,
                language: settings.language,
                createdAt: DateTime.now(),
              );

              final repo = ref.read(pageSummariesRepositoryProvider);
              await repo.saveSummary(pageSummary);

              // Invalidate cache to refresh UI
              ref.invalidate(documentSummariesProvider(widget.documentPath));

              if (!mounted) return;

              // Show the summary
              showSummaryBottomSheet(
                context: context,
                summary: pageSummary,
                onRegenerate: () => _generateSummary(regenerate: true),
                onDelete: _deleteSummary,
              );
            },
            onFailure: (message, error) {
              _showError(message);
            },
          );
        },
        onFailure: (message, error) {
          _showError(message);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _deleteSummary() async {
    final repo = ref.read(pageSummariesRepositoryProvider);
    await repo.deleteSummary(
      documentPath: widget.documentPath,
      unitNumber: widget.currentPage,
      unitType: UnitType.page,
    );
    ref.invalidate(documentSummariesProvider(widget.documentPath));
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Visualizza riassunto'),
              onTap: () {
                Navigator.pop(context);
                _showSummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Rigenera riassunto'),
              onTap: () {
                Navigator.pop(context);
                _generateSummary(regenerate: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: Text('Elimina', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showModelNotReadyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modello AI non pronto'),
        content: const Text(
          'Il modello AI deve essere scaricato e caricato prima di generare riassunti. '
          'Vai nelle impostazioni per configurare il modello.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/ai/presentation/widgets/page_summary_overlay.dart
git commit -m "feat(ui): add PageSummaryOverlay widget for PDF pages"
```

---

## Task 10: Create AiSettingsSection Widget for Settings Screen

**Files:**
- Create: `lib/features/settings/presentation/widgets/ai_settings_section.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../ai/domain/entities/ai_settings.dart';
import '../../../ai/presentation/providers/ai_settings_provider.dart';

/// Section for AI settings in the Settings screen
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  late TextEditingController _customPromptController;

  @override
  void initState() {
    super.initState();
    _customPromptController = TextEditingController();
  }

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);

    // Update controller when settings change
    if (settings.customPromptTemplate != null &&
        _customPromptController.text != settings.customPromptTemplate) {
      _customPromptController.text = settings.customPromptTemplate!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language dropdown
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Lingua riassunti'),
            subtitle: Text(settings.languageDisplayName),
            trailing: DropdownButton<String>(
              value: settings.language,
              underline: const SizedBox(),
              items: SupportedLanguages.options.map((lang) {
                return DropdownMenuItem(
                  value: lang.code,
                  child: Text(lang.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(aiSettingsProvider.notifier).setLanguage(value);
                }
              },
            ),
          ),
          const Divider(height: 1),
          // Template dropdown
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Stile riassunto'),
            subtitle: Text(_getTemplateName(settings.promptTemplateId)),
            trailing: DropdownButton<String>(
              value: settings.promptTemplateId,
              underline: const SizedBox(),
              items: PromptTemplates.options.map((template) {
                return DropdownMenuItem(
                  value: template.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(template.name),
                      Text(
                        template.description,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(aiSettingsProvider.notifier).setPromptTemplate(value);
                }
              },
            ),
          ),
          // Custom prompt field (only visible when "custom" is selected)
          if (settings.promptTemplateId == 'custom') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Template personalizzato',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customPromptController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Inserisci il tuo prompt personalizzato...',
                      border: const OutlineInputBorder(),
                      helperText: 'Variabili: {{text}}, {{language}}, {{unit_type}}, {{unit_number}}',
                      helperMaxLines: 2,
                    ),
                    onChanged: (value) {
                      ref.read(aiSettingsProvider.notifier).setCustomPrompt(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _VariableChip(label: '{{text}}', description: 'Testo della pagina'),
                      _VariableChip(label: '{{language}}', description: 'Lingua'),
                      _VariableChip(label: '{{unit_type}}', description: 'pagina/capitolo'),
                      _VariableChip(label: '{{unit_number}}', description: 'Numero'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTemplateName(String templateId) {
    return PromptTemplates.options
        .firstWhere(
          (t) => t.id == templateId,
          orElse: () => PromptTemplates.options.first,
        )
        .name;
  }
}

class _VariableChip extends StatelessWidget {
  const _VariableChip({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description,
      child: Chip(
        label: Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/settings/presentation/widgets/ai_settings_section.dart
git commit -m "feat(ui): add AiSettingsSection for language and prompt customization"
```

---

## Task 11: Integrate Overlay into Reader Screen

**Files:**
- Modify: `lib/features/reader/presentation/screens/reader_screen.dart`

**Step 1: Add import**

Add at top of file after existing imports:

```dart
import '../../../ai/presentation/widgets/page_summary_overlay.dart';
```

**Step 2: Update PDF viewer to use Stack with overlay**

Replace the PDF case in `_buildViewer()` method (lines 269-290) with:

```dart
      case DocumentType.pdf:
        return Stack(
          children: [
            SfPdfViewer.file(
              File(widget.filePath),
              controller: _pdfController,
              enableTextSelection: true,
              onPageChanged: (details) {
                setState(() {
                  _currentPage = details.newPageNumber;
                });
                // Update progress
                ref.read(recentFilesProvider.notifier).updateProgress(
                      widget.filePath,
                      details.newPageNumber,
                      _totalPages,
                    );
              },
              onDocumentLoaded: (details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                });
              },
            ),
            PageSummaryOverlay(
              documentPath: widget.filePath,
              currentPage: _currentPage,
              totalPages: _totalPages,
            ),
          ],
        );
```

**Step 3: Remove the old FAB and summarize button**

Remove the `floatingActionButton` parameter from Scaffold (lines 259-263):

```dart
// DELETE these lines:
      floatingActionButton: FloatingActionButton(
        onPressed: _generateSummary,
        tooltip: 'Generate AI Summary',
        child: const Icon(Icons.auto_awesome),
      ),
```

Remove the summarize IconButton from AppBar actions (lines 228-233):

```dart
// DELETE these lines:
          // Summarize button
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Generate Summary',
            onPressed: _generateSummary,
          ),
```

**Step 4: Remove the old `_generateSummary` method**

Delete lines 88-138 (the entire `_generateSummary` method and `_SummarizingDialog` class can be removed since we no longer need whole-document summaries).

Also remove `_showModelNotReadyDialog` method (lines 140-164) as it's now in the overlay.

**Step 5: Commit**

```bash
git add lib/features/reader/presentation/screens/reader_screen.dart
git commit -m "feat(reader): integrate PageSummaryOverlay, remove whole-doc summary"
```

---

## Task 12: Integrate AI Settings Section into Settings Screen

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Step 1: Add import**

Add at top of file:

```dart
import '../widgets/ai_settings_section.dart';
```

**Step 2: Add AI Settings section to ListView**

In the `build` method, add after the Model Settings Card section (after line 26):

```dart
          const Divider(height: 32),

          // AI Summary Settings Section
          _SectionHeader(title: 'AI Summary Settings'),
          const AiSettingsSection(),
```

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(settings): add AI settings section for language and prompt"
```

---

## Task 13: Add Chapter Summary Support for EPUB

**Files:**
- Modify: `lib/features/reader/presentation/widgets/epub_viewer.dart`

**Step 1: Add imports**

Add at top of file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ai/presentation/widgets/page_summary_overlay.dart';
```

**Step 2: Convert to ConsumerStatefulWidget**

Change class declaration:

```dart
class EpubViewer extends ConsumerStatefulWidget {
  const EpubViewer({
    super.key,
    required this.filePath,
    this.onPageChanged,
  });

  final String filePath;
  final void Function(int current, int total)? onPageChanged;

  @override
  ConsumerState<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends ConsumerState<EpubViewer> {
```

**Step 3: Add overlay to the build method**

Replace the return statement in build (starting from line 96) with:

```dart
    return Stack(
      children: [
        Column(
          children: [
            // Chapter navigation
            _ChapterNavigator(
              chapters: _chapters,
              currentIndex: _currentChapterIndex,
              onChapterSelected: (index) {
                _pageController.jumpToPage(index);
              },
            ),
            // Chapter content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _chapters.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentChapterIndex = index;
                  });
                  widget.onPageChanged?.call(index + 1, _chapters.length);
                },
                itemBuilder: (context, index) {
                  return _ChapterContent(chapter: _chapters[index]);
                },
              ),
            ),
          ],
        ),
        // Chapter summary overlay (uses chapter index + 1 as unit number)
        PageSummaryOverlay(
          documentPath: widget.filePath,
          currentPage: _currentChapterIndex + 1,
          totalPages: _chapters.length,
        ),
      ],
    );
```

**Step 4: Update PageSummaryOverlay to support chapters**

In `lib/features/ai/presentation/widgets/page_summary_overlay.dart`, add a parameter to distinguish between PDF pages and EPUB chapters. Add to constructor:

```dart
  final UnitType unitType;
```

And in the class:

```dart
  const PageSummaryOverlay({
    super.key,
    required this.documentPath,
    required this.currentPage,
    required this.totalPages,
    this.unitType = UnitType.page,
  });
```

Update `_generateSummary` to use `widget.unitType` instead of hardcoded `UnitType.page`.

Update `_deleteSummary` similarly.

**Step 5: Update EPUB viewer call**

In epub_viewer.dart, update the overlay call:

```dart
        PageSummaryOverlay(
          documentPath: widget.filePath,
          currentPage: _currentChapterIndex + 1,
          totalPages: _chapters.length,
          unitType: UnitType.chapter,
        ),
```

Add the import for UnitType:

```dart
import '../../../ai/domain/entities/page_summary.dart';
```

**Step 6: Commit**

```bash
git add lib/features/reader/presentation/widgets/epub_viewer.dart lib/features/ai/presentation/widgets/page_summary_overlay.dart
git commit -m "feat(epub): add chapter summary overlay support"
```

---

## Task 14: Update Clear Summaries in Settings

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Step 1: Add import for repository**

Add import:

```dart
import '../../../ai/presentation/providers/page_summaries_provider.dart';
```

**Step 2: Implement `_clearSummaries` method**

Replace the `_clearSummaries` method in `_DataManagementCard` (lines 357-385):

```dart
  Future<void> _clearSummaries(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella cronologia'),
        content: const Text(
          'Sei sicuro di voler eliminare tutti i riassunti salvati? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(pageSummariesRepositoryProvider);
      await repository.deleteAll();

      if (context.mounted) {
        context.showSnackBar('Cronologia cancellata');
      }
    }
  }
```

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(settings): implement clear summaries with new repository"
```

---

## Task 15: Final Testing and Cleanup

**Step 1: Run the app and test**

```bash
cd /home/gabriele/DEV/Ai-reader_standalone && flutter run
```

**Test checklist:**
- [ ] Open a PDF, verify overlay icon appears
- [ ] Tap icon on page without summary → generates and shows
- [ ] Icon turns green after generation
- [ ] Tap green icon → shows saved summary
- [ ] Change language in settings → new summaries use that language
- [ ] Change template in settings → new summaries use that template
- [ ] Custom template works with variables
- [ ] Clear summaries in settings works
- [ ] EPUB chapters work the same way

**Step 2: Run linter**

```bash
flutter analyze
```

Fix any issues found.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete page-by-page summaries with customization

- Add page_summaries table with database migration
- Create AiSettings with language and prompt templates
- Add PageSummaryOverlay for PDF pages and EPUB chapters
- Add SummaryBottomSheet for viewing/managing summaries
- Add AI settings section in Settings screen
- Remove whole-document summary functionality
- Support Italian and English languages
- Support preset and custom prompt templates"
```

---

## Summary

This implementation plan covers 15 tasks that build the page-by-page summary feature incrementally:

1. **Tasks 1-5**: Backend infrastructure (database, entities, repositories)
2. **Tasks 6-7**: State management (providers, AI repository update)
3. **Tasks 8-10**: UI components (bottom sheet, overlay, settings section)
4. **Tasks 11-14**: Integration into existing screens
5. **Task 15**: Testing and cleanup

Each task is independent enough to be committed separately, allowing for easy rollback if needed.
