import '../../../../core/utils/result.dart';
import '../entities/document.dart';

/// Service interface for document operations
abstract class DocumentService {
  /// Load a document from file path
  Future<Result<Document>> loadDocument(String filePath);

  /// Extract all text from the document
  Future<Result<String>> extractAllText(String filePath);

  /// Extract text from specific pages
  Future<Result<String>> extractTextFromPages(
    String filePath,
    int startPage,
    int endPage,
  );

  /// Get document metadata
  Future<Result<DocumentMetadata>> getMetadata(String filePath);

  /// Check if file is a valid document
  Future<bool> isValidDocument(String filePath);

  /// Get total page count
  Future<Result<int>> getPageCount(String filePath);
}
