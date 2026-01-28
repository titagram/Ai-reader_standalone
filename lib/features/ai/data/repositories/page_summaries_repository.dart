import 'package:sqflite/sqflite.dart';

import '../../../storage/data/datasources/database_helper.dart';
import '../../domain/entities/page_summary.dart';

/// Repository for managing page summaries in the database
class PageSummariesRepository {
  PageSummariesRepository();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Get all summaries for a document
  Future<Map<int, PageSummary>> getSummariesForDocument(String documentPath) async {
    final db = await _db;
    final results = await db.query(
      'page_summaries',
      where: 'document_path = ?',
      whereArgs: [documentPath],
    );

    final map = <int, PageSummary>{};
    for (final row in results) {
      final summary = PageSummary.fromMap(row);
      map[summary.unitNumber] = summary;
    }
    return map;
  }

  /// Get a specific summary
  Future<PageSummary?> getSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final db = await _db;
    final results = await db.query(
      'page_summaries',
      where: 'document_path = ? AND unit_number = ? AND unit_type = ?',
      whereArgs: [documentPath, unitNumber, unitType.name],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return PageSummary.fromMap(results.first);
  }

  /// Save or update a summary
  Future<PageSummary> saveSummary(PageSummary summary) async {
    final db = await _db;

    // Check if exists
    final existing = await getSummary(
      documentPath: summary.documentPath,
      unitNumber: summary.unitNumber,
      unitType: summary.unitType,
    );

    if (existing != null) {
      // Update
      await db.update(
        'page_summaries',
        summary.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return summary.copyWith(id: existing.id);
    } else {
      // Insert
      final id = await db.insert('page_summaries', summary.toMap());
      return summary.copyWith(id: id);
    }
  }

  /// Delete a summary
  Future<void> deleteSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final db = await _db;
    await db.delete(
      'page_summaries',
      where: 'document_path = ? AND unit_number = ? AND unit_type = ?',
      whereArgs: [documentPath, unitNumber, unitType.name],
    );
  }

  /// Delete all summaries for a document
  Future<void> deleteAllForDocument(String documentPath) async {
    final db = await _db;
    await db.delete(
      'page_summaries',
      where: 'document_path = ?',
      whereArgs: [documentPath],
    );
  }

  /// Delete all summaries
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('page_summaries');
  }

  /// Check if a summary exists
  Future<bool> hasSummary({
    required String documentPath,
    required int unitNumber,
    required UnitType unitType,
  }) async {
    final summary = await getSummary(
      documentPath: documentPath,
      unitNumber: unitNumber,
      unitType: unitType,
    );
    return summary != null;
  }
}
