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
