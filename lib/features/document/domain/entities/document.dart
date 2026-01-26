import 'package:equatable/equatable.dart';

import '../../../storage/domain/entities/recent_file.dart';

/// Document entity representing a loaded document
class Document extends Equatable {
  const Document({
    required this.filePath,
    required this.fileName,
    required this.type,
    required this.totalPages,
    this.title,
    this.author,
    this.subject,
    this.fileSize,
    this.creationDate,
  });

  final String filePath;
  final String fileName;
  final DocumentType type;
  final int totalPages;
  final String? title;
  final String? author;
  final String? subject;
  final int? fileSize;
  final DateTime? creationDate;

  /// Get display title (falls back to filename)
  String get displayTitle => title?.isNotEmpty == true ? title! : fileName;

  /// Create a copy with updated fields
  Document copyWith({
    String? filePath,
    String? fileName,
    DocumentType? type,
    int? totalPages,
    String? title,
    String? author,
    String? subject,
    int? fileSize,
    DateTime? creationDate,
  }) {
    return Document(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      totalPages: totalPages ?? this.totalPages,
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      fileSize: fileSize ?? this.fileSize,
      creationDate: creationDate ?? this.creationDate,
    );
  }

  @override
  List<Object?> get props => [
        filePath,
        fileName,
        type,
        totalPages,
        title,
        author,
        subject,
        fileSize,
        creationDate,
      ];
}

/// Document metadata for quick access
class DocumentMetadata extends Equatable {
  const DocumentMetadata({
    required this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
    this.creationDate,
    this.modificationDate,
  });

  final String title;
  final String? author;
  final String? subject;
  final String? keywords;
  final String? creator;
  final String? producer;
  final DateTime? creationDate;
  final DateTime? modificationDate;

  @override
  List<Object?> get props => [
        title,
        author,
        subject,
        keywords,
        creator,
        producer,
        creationDate,
        modificationDate,
      ];
}
