import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/result.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../../domain/entities/document.dart';
import '../../domain/services/document_service.dart';

/// PDF document service implementation using Syncfusion PDF
class PdfService implements DocumentService {
  @override
  Future<Result<Document>> loadDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);

      final pageCount = pdfDocument.pages.count;
      final info = pdfDocument.documentInformation;

      final document = Document(
        filePath: filePath,
        fileName: filePath.fileName,
        type: DocumentType.pdf,
        totalPages: pageCount,
        title: info.title.isNotEmpty ? info.title : null,
        author: info.author.isNotEmpty ? info.author : null,
        subject: info.subject.isNotEmpty ? info.subject : null,
        fileSize: await file.length(),
        creationDate: info.creationDate,
      );

      pdfDocument.dispose();
      return Result.success(document);
    } catch (e) {
      return Result.failure('Failed to load PDF document', e);
    }
  }

  @override
  Future<Result<String>> extractAllText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);

      final buffer = StringBuffer();
      final extractor = PdfTextExtractor(pdfDocument);

      for (var i = 0; i < pdfDocument.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.isNotEmpty) {
          buffer.writeln('--- Page ${i + 1} ---');
          buffer.writeln(text);
          buffer.writeln();
        }
      }

      pdfDocument.dispose();
      return Result.success(buffer.toString());
    } catch (e) {
      return Result.failure('Failed to extract text from PDF', e);
    }
  }

  @override
  Future<Result<String>> extractTextFromPages(
    String filePath,
    int startPage,
    int endPage,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);

      final extractor = PdfTextExtractor(pdfDocument);
      final text = extractor.extractText(
        startPageIndex: startPage - 1,
        endPageIndex: endPage - 1,
      );

      pdfDocument.dispose();
      return Result.success(text);
    } catch (e) {
      return Result.failure('Failed to extract text from pages', e);
    }
  }

  @override
  Future<Result<DocumentMetadata>> getMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);

      final info = pdfDocument.documentInformation;

      final metadata = DocumentMetadata(
        title: info.title.isNotEmpty ? info.title : filePath.fileName,
        author: info.author.isNotEmpty ? info.author : null,
        subject: info.subject.isNotEmpty ? info.subject : null,
        keywords: info.keywords.isNotEmpty ? info.keywords : null,
        creator: info.creator.isNotEmpty ? info.creator : null,
        producer: info.producer.isNotEmpty ? info.producer : null,
        creationDate: info.creationDate,
        modificationDate: info.modificationDate,
      );

      pdfDocument.dispose();
      return Result.success(metadata);
    } catch (e) {
      return Result.failure('Failed to get PDF metadata', e);
    }
  }

  @override
  Future<bool> isValidDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      // Check PDF magic number
      if (bytes.length < 4) return false;
      if (bytes[0] != 0x25 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x44 ||
          bytes[3] != 0x46) {
        return false;
      }

      // Try to parse the document
      final pdfDocument = PdfDocument(inputBytes: bytes);
      final isValid = pdfDocument.pages.count > 0;
      pdfDocument.dispose();
      return isValid;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Result<int>> getPageCount(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);
      final count = pdfDocument.pages.count;
      pdfDocument.dispose();

      return Result.success(count);
    } catch (e) {
      return Result.failure('Failed to get page count', e);
    }
  }
}
