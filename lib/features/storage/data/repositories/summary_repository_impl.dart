import '../../../../core/utils/result.dart';
import '../../domain/entities/summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../datasources/database_helper.dart';

/// Implementation of SummaryRepository using SQLite
class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  static const String _tableName = 'summaries';

  @override
  Future<Result<List<Summary>>> getAllSummaries() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        orderBy: 'created_at DESC',
      );
      final summaries = maps.map((map) => Summary.fromMap(map)).toList();
      return Result.success(summaries);
    } catch (e) {
      return Result.failure('Failed to get summaries', e);
    }
  }

  @override
  Future<Result<List<Summary>>> getSummariesForDocument(
      String documentPath) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'document_path = ?',
        whereArgs: [documentPath],
        orderBy: 'created_at DESC',
      );
      final summaries = maps.map((map) => Summary.fromMap(map)).toList();
      return Result.success(summaries);
    } catch (e) {
      return Result.failure('Failed to get summaries for document', e);
    }
  }

  @override
  Future<Result<Summary>> getSummaryById(int id) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) {
        return Result.failure('Summary not found');
      }
      return Result.success(Summary.fromMap(maps.first));
    } catch (e) {
      return Result.failure('Failed to get summary', e);
    }
  }

  @override
  Future<Result<Summary>> saveSummary(Summary summary) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert(_tableName, summary.toMap());
      return Result.success(summary.copyWith(id: id));
    } catch (e) {
      return Result.failure('Failed to save summary', e);
    }
  }

  @override
  Future<Result<Summary>> updateSummary(Summary summary) async {
    try {
      if (summary.id == null) {
        return Result.failure('Summary ID is required for update');
      }
      final db = await _databaseHelper.database;
      await db.update(
        _tableName,
        summary.toMap(),
        where: 'id = ?',
        whereArgs: [summary.id],
      );
      return Result.success(summary);
    } catch (e) {
      return Result.failure('Failed to update summary', e);
    }
  }

  @override
  Future<Result<void>> deleteSummary(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete summary', e);
    }
  }

  @override
  Future<Result<void>> deleteSummariesForDocument(String documentPath) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        _tableName,
        where: 'document_path = ?',
        whereArgs: [documentPath],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete summaries for document', e);
    }
  }

  @override
  Future<Result<List<Summary>>> searchSummaries(String query) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'summary_text LIKE ? OR document_name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
      final summaries = maps.map((map) => Summary.fromMap(map)).toList();
      return Result.success(summaries);
    } catch (e) {
      return Result.failure('Failed to search summaries', e);
    }
  }
}
