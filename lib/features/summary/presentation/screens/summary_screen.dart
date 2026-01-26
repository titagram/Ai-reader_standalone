import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../storage/data/repositories/summary_repository_impl.dart';
import '../../../storage/domain/entities/summary.dart';

/// Summary display screen
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({
    super.key,
    required this.summaryText,
    required this.documentName,
    this.summaryId,
  });

  final String summaryText;
  final String documentName;
  final int? summaryId;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.summaryId != null;
  }

  Future<void> _saveSummary() async {
    if (_isSaved || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final repository = SummaryRepositoryImpl(
      databaseHelper: ServiceLocator.instance.databaseHelper,
    );

    final summary = Summary(
      documentPath: '', // We don't have the full path here
      documentName: widget.documentName,
      summaryText: widget.summaryText,
      originalLength: null,
      summaryLength: widget.summaryText.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await repository.saveSummary(summary);

    if (mounted) {
      result.fold(
        onSuccess: (_) {
          setState(() {
            _isSaved = true;
            _isSaving = false;
          });
          context.showSnackBar('Summary saved');
        },
        onFailure: (message, error) {
          setState(() {
            _isSaving = false;
          });
          context.showSnackBar(message, isError: true);
        },
      );
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.summaryText));
    if (mounted) {
      context.showSnackBar('Summary copied to clipboard');
    }
  }

  Future<void> _shareSummary() async {
    await Share.share(
      '${widget.documentName}\n\n${widget.summaryText}',
      subject: 'Summary: ${widget.documentName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareSummary,
          ),
          if (!_isSaved)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Save summary',
              onPressed: _isSaving ? null : _saveSummary,
            ),
          if (_isSaved)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle, color: AppColors.success),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document name header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: context.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.documentName,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary stats
            Row(
              children: [
                _StatChip(
                  icon: Icons.short_text,
                  label: '${widget.summaryText.split(' ').length} words',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.abc,
                  label: '${widget.summaryText.length} chars',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary content
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  widget.summaryText,
                  style: context.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareSummary,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaved ? null : _saveSummary,
                    icon: _isSaved
                        ? const Icon(Icons.check)
                        : const Icon(Icons.save),
                    label: Text(_isSaved ? 'Saved' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Statistic chip widget
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
