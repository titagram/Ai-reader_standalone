import 'package:equatable/equatable.dart';

/// Summary entity representing a saved document summary
class Summary extends Equatable {
  const Summary({
    this.id,
    required this.documentPath,
    required this.documentName,
    required this.summaryText,
    this.originalLength,
    this.summaryLength,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String documentPath;
  final String documentName;
  final String summaryText;
  final int? originalLength;
  final int? summaryLength;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Create a copy with updated fields
  Summary copyWith({
    int? id,
    String? documentPath,
    String? documentName,
    String? summaryText,
    int? originalLength,
    int? summaryLength,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Summary(
      id: id ?? this.id,
      documentPath: documentPath ?? this.documentPath,
      documentName: documentName ?? this.documentName,
      summaryText: summaryText ?? this.summaryText,
      originalLength: originalLength ?? this.originalLength,
      summaryLength: summaryLength ?? this.summaryLength,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_path': documentPath,
      'document_name': documentName,
      'summary_text': summaryText,
      'original_length': originalLength,
      'summary_length': summaryLength,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from database map
  factory Summary.fromMap(Map<String, dynamic> map) {
    return Summary(
      id: map['id'] as int?,
      documentPath: map['document_path'] as String,
      documentName: map['document_name'] as String,
      summaryText: map['summary_text'] as String,
      originalLength: map['original_length'] as int?,
      summaryLength: map['summary_length'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        documentPath,
        documentName,
        summaryText,
        originalLength,
        summaryLength,
        createdAt,
        updatedAt,
      ];
}
