import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../ai/presentation/providers/ai_providers.dart';
import '../../../document/data/services/document_service_factory.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../providers/home_providers.dart';

/// Home screen with recent files and file picker
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load recent files and check model status
    Future.microtask(() {
      ref.read(recentFilesProvider.notifier).loadRecentFiles();
      ref.read(modelStateProvider.notifier).checkModelStatus();
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentServiceFactory.filePickerExtensions,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      if (mounted) {
        context.push(Routes.reader, extra: filePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentFiles = ref.watch(recentFilesProvider);
    final modelState = ref.watch(modelStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Summary History',
            onPressed: () => context.push(Routes.history),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Model Status Card
          _ModelStatusCard(modelState: modelState),

          // Recent Files Section
          Expanded(
            child: recentFiles.when(
              data: (files) => files.isEmpty
                  ? _EmptyState(onPickFile: _pickFile)
                  : _RecentFilesList(files: files),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Icons.folder_open),
        label: const Text('Open Document'),
      ),
    );
  }
}

/// Model status card widget
class _ModelStatusCard extends ConsumerWidget {
  const _ModelStatusCard({required this.modelState});

  final ModelState modelState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = modelState.currentModel;
    final isReady = modelState.isReady;
    final isDownloading = modelState.isDownloading;
    final isLoading = modelState.isLoading;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isReady
                      ? Icons.check_circle
                      : isDownloading || isLoading
                          ? Icons.downloading
                          : Icons.cloud_download,
                  color: isReady
                      ? AppColors.success
                      : isDownloading || isLoading
                          ? AppColors.info
                          : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Model',
                        style: context.textTheme.titleMedium,
                      ),
                      Text(
                        model?.displayName ?? 'Gemma 3B',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(context, ref),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: modelState.downloadProgress,
              ),
              const SizedBox(height: 4),
              Text(
                '${(modelState.downloadProgress * 100).toStringAsFixed(1)}%',
                style: context.textTheme.bodySmall,
              ),
            ],
            if (modelState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                modelState.error!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(modelStateProvider.notifier);

    if (modelState.isReady) {
      return TextButton(
        onPressed: () => notifier.unloadModel(),
        child: const Text('Unload'),
      );
    }

    if (modelState.isDownloading) {
      return TextButton(
        onPressed: () => notifier.cancelDownload(),
        child: const Text('Cancel'),
      );
    }

    if (modelState.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (modelState.currentModel?.isDownloaded == true) {
      return ElevatedButton(
        onPressed: () => notifier.loadModel(),
        child: const Text('Load'),
      );
    }

    return ElevatedButton(
      onPressed: () => notifier.downloadModel(),
      child: const Text('Download'),
    );
  }
}

/// Empty state when no recent files
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: context.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent documents',
            style: context.textTheme.titleLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a PDF or EPUB to get started',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Document'),
          ),
        ],
      ),
    );
  }
}

/// Recent files list widget
class _RecentFilesList extends StatelessWidget {
  const _RecentFilesList({required this.files});

  final List<RecentFile> files;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: files.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'Recent Documents',
              style: context.textTheme.titleMedium,
            ),
          );
        }

        final file = files[index - 1];
        return _RecentFileCard(file: file);
      },
    );
  }
}

/// Recent file card widget
class _RecentFileCard extends StatelessWidget {
  const _RecentFileCard({required this.file});

  final RecentFile file;

  @override
  Widget build(BuildContext context) {
    final exists = File(file.filePath).existsSync();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: exists
              ? _getColorForType(file.fileType)
              : context.colorScheme.surfaceContainerHighest,
          child: Icon(
            _getIconForType(file.fileType),
            color: exists
                ? Colors.white
                : context.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: exists ? null : context.colorScheme.onSurfaceVariant,
            decoration: exists ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          exists
              ? file.lastOpenedAt.relativeTime
              : 'File not found',
          style: TextStyle(
            color: exists ? null : AppColors.error,
          ),
        ),
        trailing: file.totalPages != null
            ? Text(
                '${file.lastPage}/${file.totalPages}',
                style: context.textTheme.bodySmall,
              )
            : null,
        enabled: exists,
        onTap: exists
            ? () => context.push(Routes.reader, extra: file.filePath)
            : null,
      ),
    );
  }

  IconData _getIconForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.epub:
        return Icons.book;
      case DocumentType.unknown:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.epub:
        return Colors.blue;
      case DocumentType.unknown:
        return Colors.grey;
    }
  }
}
