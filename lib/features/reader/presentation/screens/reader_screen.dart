import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../ai/presentation/providers/ai_providers.dart';
import '../../../document/data/services/document_service_factory.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../providers/reader_providers.dart';
import '../widgets/epub_viewer.dart';

/// Document reader screen supporting PDF and EPUB
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.filePath,
  });

  final String filePath;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PdfViewerController _pdfController;
  bool _isLoading = true;
  String? _error;
  DocumentType? _documentType;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _initializeDocument();
  }

  Future<void> _initializeDocument() async {
    try {
      final extension = widget.filePath.fileExtension.toLowerCase();
      _documentType = DocumentType.fromExtension(extension);

      final service = DocumentServiceFactory.getServiceForFile(widget.filePath);
      final result = await service.loadDocument(widget.filePath);

      result.fold(
        onSuccess: (document) {
          setState(() {
            _totalPages = document.totalPages;
            _isLoading = false;
          });

          // Update recent files
          ref.read(recentFilesProvider.notifier).addRecentFile(
                RecentFile(
                  filePath: widget.filePath,
                  fileName: document.fileName,
                  fileType: document.type,
                  fileSize: document.fileSize,
                  lastOpenedAt: DateTime.now(),
                  totalPages: document.totalPages,
                ),
              );
        },
        onFailure: (message, error) {
          setState(() {
            _error = message;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateSummary() async {
    // Check if model is ready
    final modelState = ref.read(modelStateProvider);
    if (!modelState.isReady) {
      _showModelNotReadyDialog();
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SummarizingDialog(),
    );

    // Extract text
    final service = DocumentServiceFactory.getServiceForFile(widget.filePath);
    final textResult = await service.extractAllText(widget.filePath);

    if (!mounted) return;

    textResult.fold(
      onSuccess: (text) async {
        if (text.isEmpty) {
          Navigator.pop(context);
          _showErrorSnackBar('No text found in document');
          return;
        }

        // Generate summary
        await ref.read(summarizationProvider.notifier).generateSummary(text);

        if (!mounted) return;
        Navigator.pop(context);

        final summaryState = ref.read(summarizationProvider);
        if (summaryState.summary != null) {
          context.push(Routes.summary, extra: {
            'summaryText': summaryState.summary,
            'documentName': widget.filePath.fileName,
          });
        } else if (summaryState.error != null) {
          _showErrorSnackBar(summaryState.error!);
        }
      },
      onFailure: (message, error) {
        Navigator.pop(context);
        _showErrorSnackBar(message);
      },
    );
  }

  void _showModelNotReadyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Model Not Ready'),
        content: const Text(
          'The AI model needs to be downloaded and loaded before generating summaries. '
          'Would you like to go to settings to configure the model?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.settings);
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filePath.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Page indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_currentPage / $_totalPages',
                style: context.textTheme.bodyMedium,
              ),
            ),
          ),
          // Summarize button
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Generate Summary',
            onPressed: _generateSummary,
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'annotations',
                child: ListTile(
                  leading: Icon(Icons.highlight),
                  title: Text('Annotations'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Document Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildViewer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateSummary,
        tooltip: 'Generate AI Summary',
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildViewer() {
    switch (_documentType) {
      case DocumentType.pdf:
        return SfPdfViewer.file(
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
        );
      case DocumentType.epub:
        return EpubViewer(
          filePath: widget.filePath,
          onPageChanged: (current, total) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
            });
          },
        );
      default:
        return const Center(
          child: Text('Unsupported document type'),
        );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'annotations':
        // TODO: Show annotations panel
        break;
      case 'info':
        _showDocumentInfo();
        break;
    }
  }

  Future<void> _showDocumentInfo() async {
    final service = DocumentServiceFactory.getServiceForFile(widget.filePath);
    final result = await service.getMetadata(widget.filePath);

    if (!mounted) return;

    result.fold(
      onSuccess: (metadata) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Document Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow('Title', metadata.title),
                if (metadata.author != null)
                  _InfoRow('Author', metadata.author!),
                if (metadata.subject != null)
                  _InfoRow('Subject', metadata.subject!),
                _InfoRow('Pages', _totalPages.toString()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      onFailure: (message, error) {
        _showErrorSnackBar(message);
      },
    );
  }
}

/// Info row widget for document info dialog
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

/// Dialog shown during summarization
class _SummarizingDialog extends StatelessWidget {
  const _SummarizingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generating Summary',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'AI is analyzing the document...',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
