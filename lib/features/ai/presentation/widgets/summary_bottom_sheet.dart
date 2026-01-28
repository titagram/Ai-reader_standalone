import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/page_summary.dart';

/// Bottom sheet for displaying and managing a page/chapter summary
class SummaryBottomSheet extends StatelessWidget {
  const SummaryBottomSheet({
    super.key,
    required this.summary,
    required this.onRegenerate,
    required this.onDelete,
  });

  final PageSummary summary;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unitLabel = summary.unitType == UnitType.page ? 'Pagina' : 'Capitolo';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  summary.unitType == UnitType.page
                      ? Icons.description
                      : Icons.book,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '$unitLabel ${summary.unitNumber}',
                  style: context.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                summary.summaryText,
                style: context.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onRegenerate();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rigenera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: summary.summaryText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copiato negli appunti')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Elimina',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina riassunto'),
        content: const Text(
          'Sei sicuro di voler eliminare questo riassunto? Dovrai rigenerarlo se ti serve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

/// Show the summary bottom sheet
Future<void> showSummaryBottomSheet({
  required BuildContext context,
  required PageSummary summary,
  required VoidCallback onRegenerate,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SummaryBottomSheet(
      summary: summary,
      onRegenerate: onRegenerate,
      onDelete: onDelete,
    ),
  );
}
