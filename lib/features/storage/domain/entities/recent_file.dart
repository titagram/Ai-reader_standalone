import 'package:equatable/equatable.dart';

/// Document type enumeration
enum DocumentType {
  pdf,
  epub,
  unknown;

  /// Get document type from file extension
  static DocumentType fromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return DocumentType.pdf;
      case '.epub':
        return DocumentType.epub;
      default:
        return DocumentType.unknown;
    }
  }

  /// Get display name
  String get displayName {
    switch (this) {
      case DocumentType.pdf:
        return 'PDF';
      case DocumentType.epub:
        return 'EPUB';
      case DocumentType.unknown:
        return 'Unknown';
    }
  }
}

/// Recent file entity representing a recently opened document
class RecentFile extends Equatable {
  const RecentFile({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.fileSize,
    required this.lastOpenedAt,
    this.lastPage = 0,
    this.totalPages,
  });

  final int? id;
  final String filePath;
  final String fileName;
  final DocumentType fileType;
  final int? fileSize;
  final DateTime lastOpenedAt;
  final int lastPage;
  final int? totalPages;

  /// Get reading progress as percentage
  double get readingProgress {
    if (totalPages == null || totalPages == 0) return 0;
    return (lastPage / totalPages!) * 100;
  }

  /// Create a copy with updated fields
  RecentFile copyWith({
    int? id,
    String? filePath,
    String? fileName,
    DocumentType? fileType,
    int? fileSize,
    DateTime? lastOpenedAt,
    int? lastPage,
    int? totalPages,
  }) {
    return RecentFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType.name,
      'file_size': fileSize,
      'last_opened_at': lastOpenedAt.toIso8601String(),
      'last_page': lastPage,
      'total_pages': totalPages,
    };
  }

  /// Create from database map
  factory RecentFile.fromMap(Map<String, dynamic> map) {
    return RecentFile(
      id: map['id'] as int?,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileType: DocumentType.values.byName(map['file_type'] as String),
      fileSize: map['file_size'] as int?,
      lastOpenedAt: DateTime.parse(map['last_opened_at'] as String),
      lastPage: map['last_page'] as int? ?? 0,
      totalPages: map['total_pages'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        filePath,
        fileName,
        fileType,
        fileSize,
        lastOpenedAt,
        lastPage,
        totalPages,
      ];
}
