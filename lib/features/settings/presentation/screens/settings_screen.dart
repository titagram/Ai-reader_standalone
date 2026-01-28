import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../ai/domain/entities/model_info.dart';
import '../../../ai/presentation/providers/ai_providers.dart';
import '../widgets/ai_settings_section.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // AI Model Section
          _SectionHeader(title: 'AI Model'),
          _ModelSettingsCard(modelState: modelState),

          const Divider(height: 32),

          // AI Summary Settings Section
          _SectionHeader(title: 'AI Summary Settings'),
          const AiSettingsSection(),

          const Divider(height: 32),

          // About Section
          _SectionHeader(title: 'About'),
          _AboutCard(),

          const Divider(height: 32),

          // Danger Zone
          _SectionHeader(title: 'Data Management'),
          _DataManagementCard(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Model settings card
class _ModelSettingsCard extends ConsumerWidget {
  const _ModelSettingsCard({required this.modelState});

  final ModelState modelState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = modelState.currentModel ?? DefaultModels.gemma3bInt4;
    final notifier = ref.read(modelStateProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(model.status),
              child: Icon(
                _getStatusIcon(model.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(model.displayName),
            subtitle: Text(_getStatusText(model.status)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.description,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(label: model.parameters),
                    const SizedBox(width: 8),
                    _InfoChip(label: model.quantization),
                    const SizedBox(width: 8),
                    _InfoChip(label: model.fileSizeFormatted),
                  ],
                ),
              ],
            ),
          ),
          if (modelState.isDownloading) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: modelState.downloadProgress,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloading: ${(modelState.downloadProgress * 100).toStringAsFixed(1)}%',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          if (modelState.error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                modelState.error!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (model.status == ModelStatus.notDownloaded ||
                    model.status == ModelStatus.error)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => notifier.downloadModel(),
                      child: const Text('Download Model'),
                    ),
                  ),
                if (modelState.isDownloading)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => notifier.cancelDownload(),
                      child: const Text('Cancel'),
                    ),
                  ),
                if (model.status == ModelStatus.downloaded)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => notifier.loadModel(),
                      child: const Text('Load Model'),
                    ),
                  ),
                if (model.status == ModelStatus.loaded) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => notifier.unloadModel(),
                      child: const Text('Unload'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (modelState.isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.loaded:
        return AppColors.success;
      case ModelStatus.downloaded:
      case ModelStatus.loading:
        return AppColors.info;
      case ModelStatus.downloading:
        return AppColors.warning;
      case ModelStatus.notDownloaded:
        return Colors.grey;
      case ModelStatus.error:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(ModelStatus status) {
    switch (status) {
      case ModelStatus.loaded:
        return Icons.check;
      case ModelStatus.downloaded:
        return Icons.download_done;
      case ModelStatus.loading:
        return Icons.hourglass_top;
      case ModelStatus.downloading:
        return Icons.downloading;
      case ModelStatus.notDownloaded:
        return Icons.cloud_download;
      case ModelStatus.error:
        return Icons.error;
    }
  }

  String _getStatusText(ModelStatus status) {
    switch (status) {
      case ModelStatus.loaded:
        return 'Model is loaded and ready for inference';
      case ModelStatus.downloaded:
        return 'Model downloaded, tap to load';
      case ModelStatus.loading:
        return 'Loading model into memory...';
      case ModelStatus.downloading:
        return 'Downloading model...';
      case ModelStatus.notDownloaded:
        return 'Model not downloaded yet';
      case ModelStatus.error:
        return 'Error occurred';
    }
  }
}

/// Info chip widget
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall,
      ),
    );
  }
}

/// About card
class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Powered by'),
            subtitle: const Text('Google Gemma 3B'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text('All processing happens locally on your device'),
          ),
        ],
      ),
    );
  }
}

/// Data management card
class _DataManagementCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear Summary History'),
            subtitle: const Text('Delete all saved summaries'),
            onTap: () => _clearSummaries(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: AppColors.error),
            title: Text(
              'Delete Downloaded Model',
              style: TextStyle(color: AppColors.error),
            ),
            subtitle: const Text('Free up storage space'),
            onTap: () => _deleteModel(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSummaries(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to delete all saved summaries? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement clear summaries
      if (context.mounted) {
        context.showSnackBar('History cleared');
      }
    }
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: const Text(
          'Are you sure you want to delete the downloaded model? '
          'You will need to download it again to use AI features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement delete model
      if (context.mounted) {
        context.showSnackBar('Model deleted');
      }
    }
  }
}
