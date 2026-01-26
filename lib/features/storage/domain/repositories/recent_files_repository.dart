import '../../../../core/utils/result.dart';
import '../entities/recent_file.dart';

/// Repository interface for recent files operations
abstract class RecentFilesRepository {
  /// Get all recent files ordered by last opened date
  Future<Result<List<RecentFile>>> getRecentFiles({int limit = 10});

  /// Get a recent file by path
  Future<Result<RecentFile?>> getRecentFileByPath(String filePath);

  /// Add or update a recent file
  Future<Result<RecentFile>> addOrUpdateRecentFile(RecentFile recentFile);

  /// Update reading progress for a file
  Future<Result<void>> updateReadingProgress(
    String filePath,
    int currentPage,
    int? totalPages,
  );

  /// Remove a file from recent history
  Future<Result<void>> removeRecentFile(String filePath);

  /// Clear all recent files
  Future<Result<void>> clearRecentFiles();
}
