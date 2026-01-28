import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../document/data/services/document_service_factory.dart';
import '../../domain/entities/page_summary.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/page_summaries_provider.dart';
import 'summary_bottom_sheet.dart';

/// Overlay icon for page summary (positioned on PDF pages)
class PageSummaryOverlay extends ConsumerStatefulWidget {
  const PageSummaryOverlay({
    super.key,
    required this.documentPath,
    required this.currentPage,
    required this.totalPages,
    this.unitType = UnitType.page,
  });

  final String documentPath;
  final int currentPage;
  final int totalPages;
  final UnitType unitType;

  @override
  ConsumerState<PageSummaryOverlay> createState() => _PageSummaryOverlayState();
}

class _PageSummaryOverlayState extends ConsumerState<PageSummaryOverlay> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final hasSummary = ref.watch(
      hasPageSummaryProvider(
        (documentPath: widget.documentPath, unitNumber: widget.currentPage),
      ),
    );

    final modelState = ref.watch(modelStateProvider);

    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.currentPage}/${widget.totalPages}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          // Summary button
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: _getButtonColor(hasSummary),
            child: InkWell(
              onTap: _isGenerating || !modelState.isReady
                  ? null
                  : () => _handleTap(hasSummary),
              onLongPress: hasSummary ? () => _showOptions() : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: _buildIcon(hasSummary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor(bool hasSummary) {
    if (_isGenerating) return Colors.orange;
    if (hasSummary) return AppColors.success;
    return Colors.grey.shade600;
  }

  Widget _buildIcon(bool hasSummary) {
    if (_isGenerating) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }
    return Icon(
      hasSummary ? Icons.auto_awesome : Icons.auto_awesome_outlined,
      color: Colors.white,
      size: 24,
    );
  }

  Future<void> _handleTap(bool hasSummary) async {
    if (hasSummary) {
      _showSummary();
    } else {
      await _generateSummary();
    }
  }

  void _showSummary() {
    final summary = ref.read(
      pageSummaryProvider(
        (documentPath: widget.documentPath, unitNumber: widget.currentPage),
      ),
    );

    if (summary == null) return;

    showSummaryBottomSheet(
      context: context,
      summary: summary,
      onRegenerate: () => _generateSummary(regenerate: true),
      onDelete: _deleteSummary,
    );
  }

  Future<void> _generateSummary({bool regenerate = false}) async {
    final modelState = ref.read(modelStateProvider);
    if (!modelState.isReady) {
      _showModelNotReadyDialog();
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Extract text for current page
      final service = DocumentServiceFactory.getServiceForFile(widget.documentPath);
      final textResult = await service.extractTextFromPages(
        widget.documentPath,
        widget.currentPage,
        widget.currentPage,
      );

      if (!mounted) return;

      await textResult.fold(
        onSuccess: (text) async {
          if (text.isEmpty) {
            _showError('Nessun testo trovato in questa pagina');
            return;
          }

          // Get settings and build prompt
          final settings = ref.read(aiSettingsProvider);
          final prompt = settings.buildPrompt(
            text: text,
            unitType: settings.language == 'it'
                ? widget.unitType.displayName
                : widget.unitType.displayNameEn,
            unitNumber: widget.currentPage,
          );

          // Generate summary
          final repository = ref.read(aiModelRepositoryProvider);
          final result = await repository.generateWithCustomPrompt(prompt);

          if (!mounted) return;

          await result.fold(
            onSuccess: (summaryText) async {
              // Save to database
              final pageSummary = PageSummary(
                documentPath: widget.documentPath,
                unitNumber: widget.currentPage,
                unitType: widget.unitType,
                summaryText: summaryText,
                promptTemplateId: settings.promptTemplateId,
                language: settings.language,
                createdAt: DateTime.now(),
              );

              final repo = ref.read(pageSummariesRepositoryProvider);
              await repo.saveSummary(pageSummary);

              // Invalidate cache to refresh UI
              ref.invalidate(documentSummariesProvider(widget.documentPath));

              if (!mounted) return;

              // Show the summary
              showSummaryBottomSheet(
                context: context,
                summary: pageSummary,
                onRegenerate: () => _generateSummary(regenerate: true),
                onDelete: _deleteSummary,
              );
            },
            onFailure: (message, error) {
              _showError(message);
            },
          );
        },
        onFailure: (message, error) {
          _showError(message);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _deleteSummary() async {
    final repo = ref.read(pageSummariesRepositoryProvider);
    await repo.deleteSummary(
      documentPath: widget.documentPath,
      unitNumber: widget.currentPage,
      unitType: widget.unitType,
    );
    ref.invalidate(documentSummariesProvider(widget.documentPath));
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Visualizza riassunto'),
              onTap: () {
                Navigator.pop(context);
                _showSummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Rigenera riassunto'),
              onTap: () {
                Navigator.pop(context);
                _generateSummary(regenerate: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Elimina', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showModelNotReadyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modello AI non pronto'),
        content: const Text(
          'Il modello AI deve essere scaricato e caricato prima di generare riassunti. '
          'Vai nelle impostazioni per configurare il modello.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
