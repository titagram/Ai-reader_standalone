import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_locator.dart';
import '../../../storage/data/repositories/recent_files_repository_impl.dart';
import '../../../storage/domain/entities/recent_file.dart';
import '../../../storage/domain/repositories/recent_files_repository.dart';

/// Provider for recent files repository
final recentFilesRepositoryProvider = Provider<RecentFilesRepository>((ref) {
  return RecentFilesRepositoryImpl(
    databaseHelper: ServiceLocator.instance.databaseHelper,
  );
});

/// State notifier for recent files
class RecentFilesNotifier extends StateNotifier<AsyncValue<List<RecentFile>>> {
  RecentFilesNotifier(this._repository) : super(const AsyncValue.loading());

  final RecentFilesRepository _repository;

  /// Load recent files
  Future<void> loadRecentFiles() async {
    state = const AsyncValue.loading();

    final result = await _repository.getRecentFiles(limit: 10);

    result.fold(
      onSuccess: (files) {
        state = AsyncValue.data(files);
      },
      onFailure: (message, error) {
        state = AsyncValue.error(message, StackTrace.current);
      },
    );
  }

  /// Add or update a recent file
  Future<void> addRecentFile(RecentFile file) async {
    final result = await _repository.addOrUpdateRecentFile(file);

    result.fold(
      onSuccess: (_) => loadRecentFiles(),
      onFailure: (message, error) {
        // Silently fail, just log
      },
    );
  }

  /// Remove a recent file
  Future<void> removeRecentFile(String filePath) async {
    final result = await _repository.removeRecentFile(filePath);

    result.fold(
      onSuccess: (_) => loadRecentFiles(),
      onFailure: (message, error) {
        // Silently fail
      },
    );
  }

  /// Update reading progress
  Future<void> updateProgress(
    String filePath,
    int currentPage,
    int? totalPages,
  ) async {
    await _repository.updateReadingProgress(filePath, currentPage, totalPages);
    // Don't reload to avoid UI flicker
  }
}

/// Provider for recent files state
final recentFilesProvider =
    StateNotifierProvider<RecentFilesNotifier, AsyncValue<List<RecentFile>>>(
        (ref) {
  final repository = ref.watch(recentFilesRepositoryProvider);
  return RecentFilesNotifier(repository);
});
