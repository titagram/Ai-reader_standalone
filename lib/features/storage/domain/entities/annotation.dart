import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Annotation entity representing a highlight or note on a document
class Annotation extends Equatable {
  const Annotation({
    this.id,
    required this.documentPath,
    required this.pageNumber,
    this.selectedText,
    this.noteText,
    required this.highlightColor,
    this.startIndex,
    this.endIndex,
    this.bounds,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String documentPath;
  final int pageNumber;
  final String? selectedText;
  final String? noteText;
  final Color highlightColor;
  final int? startIndex;
  final int? endIndex;
  final AnnotationBounds? bounds;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Check if this annotation has a note
  bool get hasNote => noteText != null && noteText!.isNotEmpty;

  /// Check if this annotation has selected text
  bool get hasSelectedText => selectedText != null && selectedText!.isNotEmpty;

  /// Create a copy with updated fields
  Annotation copyWith({
    int? id,
    String? documentPath,
    int? pageNumber,
    String? selectedText,
    String? noteText,
    Color? highlightColor,
    int? startIndex,
    int? endIndex,
    AnnotationBounds? bounds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      documentPath: documentPath ?? this.documentPath,
      pageNumber: pageNumber ?? this.pageNumber,
      selectedText: selectedText ?? this.selectedText,
      noteText: noteText ?? this.noteText,
      highlightColor: highlightColor ?? this.highlightColor,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      bounds: bounds ?? this.bounds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_path': documentPath,
      'page_number': pageNumber,
      'selected_text': selectedText,
      'note_text': noteText,
      'highlight_color': highlightColor.value,
      'start_index': startIndex,
      'end_index': endIndex,
      'bounds_json': bounds?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from database map
  factory Annotation.fromMap(Map<String, dynamic> map) {
    return Annotation(
      id: map['id'] as int?,
      documentPath: map['document_path'] as String,
      pageNumber: map['page_number'] as int,
      selectedText: map['selected_text'] as String?,
      noteText: map['note_text'] as String?,
      highlightColor: Color(map['highlight_color'] as int),
      startIndex: map['start_index'] as int?,
      endIndex: map['end_index'] as int?,
      bounds: map['bounds_json'] != null
          ? AnnotationBounds.fromJson(map['bounds_json'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        documentPath,
        pageNumber,
        selectedText,
        noteText,
        highlightColor,
        startIndex,
        endIndex,
        bounds,
        createdAt,
        updatedAt,
      ];
}

/// Bounds for annotation positioning
class AnnotationBounds extends Equatable {
  const AnnotationBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Convert to Rect
  Rect toRect() => Rect.fromLTRB(left, top, right, bottom);

  /// Create from Rect
  factory AnnotationBounds.fromRect(Rect rect) {
    return AnnotationBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    );
  }

  /// Convert to JSON string
  String toJson() {
    return jsonEncode({
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    });
  }

  /// Create from JSON string
  factory AnnotationBounds.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return AnnotationBounds(
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      right: (map['right'] as num).toDouble(),
      bottom: (map['bottom'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [left, top, right, bottom];
}
