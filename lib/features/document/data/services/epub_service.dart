import 'dart:io';

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/result.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../../domain/entities/document.dart';
import '../../domain/services/document_service.dart';

/// EPUB document service implementation using epubx
class EpubService implements DocumentService {
  @override
  Future<Result<Document>> loadDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Result.failure('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      // Count chapters/sections as "pages" for EPUB
      final chapterCount = _getChapterCount(epubBook);

      final document = Document(
        filePath: filePath,
        fileName: filePath.fileName,
        type: DocumentType.epub,
        totalPages: chapterCount,
        title: epubBook.Title,
        author: epubBook.Author,
        fileSize: await file.length(),
      );

      return Result.success(document);
    } catch (e) {
      return Result.failure('Failed to load EPUB document', e);
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
      final epubBook = await EpubReader.readBook(bytes);

      final buffer = StringBuffer();
      final chapters = epubBook.Chapters ?? [];

      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        buffer.writeln('--- ${chapter.Title ?? 'Chapter ${i + 1}'} ---');
        final text = _extractTextFromChapter(chapter);
        buffer.writeln(text);
        buffer.writeln();
      }

      return Result.success(buffer.toString());
    } catch (e) {
      return Result.failure('Failed to extract text from EPUB', e);
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
      final epubBook = await EpubReader.readBook(bytes);

      final buffer = StringBuffer();
      final chapters = epubBook.Chapters ?? [];

      // Adjust for 0-based indexing
      final start = (startPage - 1).clamp(0, chapters.length - 1);
      final end = (endPage - 1).clamp(0, chapters.length - 1);

      for (var i = start; i <= end; i++) {
        final chapter = chapters[i];
        final text = _extractTextFromChapter(chapter);
        buffer.writeln(text);
        buffer.writeln();
      }

      return Result.success(buffer.toString());
    } catch (e) {
      return Result.failure('Failed to extract text from chapters', e);
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
      final epubBook = await EpubReader.readBook(bytes);

      final metadata = DocumentMetadata(
        title: epubBook.Title ?? filePath.fileName,
        author: epubBook.Author,
      );

      return Result.success(metadata);
    } catch (e) {
      return Result.failure('Failed to get EPUB metadata', e);
    }
  }

  @override
  Future<bool> isValidDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();

      // Check ZIP magic number (EPUB is a ZIP file)
      if (bytes.length < 4) return false;
      if (bytes[0] != 0x50 || bytes[1] != 0x4B) {
        return false;
      }

      // Try to decode as archive
      final archive = ZipDecoder().decodeBytes(bytes);

      // Check for mimetype file with application/epub+zip
      final mimeFile = archive.findFile('mimetype');
      if (mimeFile == null) return false;

      final mimeContent = String.fromCharCodes(mimeFile.content as List<int>);
      return mimeContent.trim() == 'application/epub+zip';
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
      final epubBook = await EpubReader.readBook(bytes);

      return Result.success(_getChapterCount(epubBook));
    } catch (e) {
      return Result.failure('Failed to get chapter count', e);
    }
  }

  /// Get total chapter count including sub-chapters
  int _getChapterCount(EpubBook book) {
    int count = 0;
    final chapters = book.Chapters ?? [];

    for (final chapter in chapters) {
      count++;
      count += _countSubChapters(chapter);
    }

    return count > 0 ? count : 1;
  }

  /// Recursively count sub-chapters
  int _countSubChapters(EpubChapter chapter) {
    int count = 0;
    final subChapters = chapter.SubChapters ?? [];

    for (final subChapter in subChapters) {
      count++;
      count += _countSubChapters(subChapter);
    }

    return count;
  }

  /// Extract plain text from a chapter, removing HTML tags
  String _extractTextFromChapter(EpubChapter chapter) {
    final buffer = StringBuffer();

    // Extract text from chapter content
    final content = chapter.HtmlContent ?? '';
    final text = _stripHtmlTags(content);
    buffer.writeln(text);

    // Process sub-chapters
    final subChapters = chapter.SubChapters ?? [];
    for (final subChapter in subChapters) {
      buffer.writeln(_extractTextFromChapter(subChapter));
    }

    return buffer.toString().trim();
  }

  /// Strip HTML tags from content
  String _stripHtmlTags(String html) {
    // Remove script and style elements
    var text = html.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );

    // Replace common block elements with newlines
    text = text.replaceAll(
      RegExp(r'</(p|div|br|h[1-6]|li|tr)>', caseSensitive: false),
      '\n',
    );

    // Remove remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode common HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    text = text.replaceAll(RegExp(r' +'), ' ');

    return text.trim();
  }
}
