import '../../../../core/utils/extensions.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../../domain/services/document_service.dart';
import 'epub_service.dart';
import 'pdf_service.dart';

/// Factory for creating document services based on file type
class DocumentServiceFactory {
  DocumentServiceFactory._();

  static final _pdfService = PdfService();
  static final _epubService = EpubService();

  /// Get document service for file path
  static DocumentService getServiceForFile(String filePath) {
    final extension = filePath.fileExtension.toLowerCase();
    return getServiceForExtension(extension);
  }

  /// Get document service for file extension
  static DocumentService getServiceForExtension(String extension) {
    final type = DocumentType.fromExtension(extension);
    return getServiceForType(type);
  }

  /// Get document service for document type
  static DocumentService getServiceForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return _pdfService;
      case DocumentType.epub:
        return _epubService;
      case DocumentType.unknown:
        throw UnsupportedError('Unsupported document type');
    }
  }

  /// Check if file extension is supported
  static bool isSupported(String filePath) {
    final extension = filePath.fileExtension.toLowerCase();
    return extension == '.pdf' || extension == '.epub';
  }

  /// Get supported extensions
  static List<String> get supportedExtensions => ['.pdf', '.epub'];

  /// Get file filter for file picker
  static List<String> get filePickerExtensions => ['pdf', 'epub'];
}
