import '../../../../core/utils/result.dart';
import '../../domain/entities/recent_file.dart';
import '../../domain/repositories/recent_files_repository.dart';
import '../datasources/database_helper.dart';

/// Implementation of RecentFilesRepository using SQLite
class RecentFilesRepositoryImpl implements RecentFilesRepository {
  RecentFilesRepositoryImpl({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  static const String _tableName = 'recent_files';

  @override
  Future<Result<List<RecentFile>>> getRecentFiles({int limit = 10}) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        orderBy: 'last_opened_at DESC',
        limit: limit,
      );
      final files = maps.map((map) => RecentFile.fromMap(map)).toList();
      return Result.success(files);
    } catch (e) {
      return Result.failure('Failed to get recent files', e);
    }
  }

  @override
  Future<Result<RecentFile?>> getRecentFileByPath(String filePath) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'file_path = ?',
        whereArgs: [filePath],
        limit: 1,
      );
      if (maps.isEmpty) {
        return Result.success(null);
      }
      return Result.success(RecentFile.fromMap(maps.first));
    } catch (e) {
      return Result.failure('Failed to get recent file', e);
    }
  }

  @override
  Future<Result<RecentFile>> addOrUpdateRecentFile(
      RecentFile recentFile) async {
    try {
      final db = await _databaseHelper.database;

      // Check if file already exists
      final existing = await db.query(
        _tableName,
        where: 'file_path = ?',
        whereArgs: [recentFile.filePath],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing
        final existingFile = RecentFile.fromMap(existing.first);
        final updated = recentFile.copyWith(id: existingFile.id);
        await db.update(
          _tableName,
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [existingFile.id],
        );
        return Result.success(updated);
      } else {
        // Insert new
        final id = await db.insert(_tableName, recentFile.toMap());
        return Result.success(recentFile.copyWith(id: id));
      }
    } catch (e) {
      return Result.failure('Failed to add or update recent file', e);
    }
  }

  @override
  Future<Result<void>> updateReadingProgress(
    String filePath,
    int currentPage,
    int? totalPages,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final updates = <String, dynamic>{
        'last_page': currentPage,
        'last_opened_at': DateTime.now().toIso8601String(),
      };
      if (totalPages != null) {
        updates['total_pages'] = totalPages;
      }
      await db.update(
        _tableName,
        updates,
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update reading progress', e);
    }
  }

  @override
  Future<Result<void>> removeRecentFile(String filePath) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        _tableName,
        where: 'file_path = ?',
        whereArgs: [filePath],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to remove recent file', e);
    }
  }

  @override
  Future<Result<void>> clearRecentFiles() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(_tableName);
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to clear recent files', e);
    }
  }
}
