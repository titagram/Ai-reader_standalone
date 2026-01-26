import '../../../../core/utils/result.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/repositories/annotation_repository.dart';
import '../datasources/database_helper.dart';

/// Implementation of AnnotationRepository using SQLite
class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  static const String _tableName = 'annotations';

  @override
  Future<Result<List<Annotation>>> getAnnotationsForDocument(
      String documentPath) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'document_path = ?',
        whereArgs: [documentPath],
        orderBy: 'page_number ASC, created_at ASC',
      );
      final annotations = maps.map((map) => Annotation.fromMap(map)).toList();
      return Result.success(annotations);
    } catch (e) {
      return Result.failure('Failed to get annotations', e);
    }
  }

  @override
  Future<Result<List<Annotation>>> getAnnotationsForPage(
    String documentPath,
    int pageNumber,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'document_path = ? AND page_number = ?',
        whereArgs: [documentPath, pageNumber],
        orderBy: 'created_at ASC',
      );
      final annotations = maps.map((map) => Annotation.fromMap(map)).toList();
      return Result.success(annotations);
    } catch (e) {
      return Result.failure('Failed to get annotations for page', e);
    }
  }

  @override
  Future<Result<Annotation>> getAnnotationById(int id) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) {
        return Result.failure('Annotation not found');
      }
      return Result.success(Annotation.fromMap(maps.first));
    } catch (e) {
      return Result.failure('Failed to get annotation', e);
    }
  }

  @override
  Future<Result<Annotation>> saveAnnotation(Annotation annotation) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert(_tableName, annotation.toMap());
      return Result.success(annotation.copyWith(id: id));
    } catch (e) {
      return Result.failure('Failed to save annotation', e);
    }
  }

  @override
  Future<Result<Annotation>> updateAnnotation(Annotation annotation) async {
    try {
      if (annotation.id == null) {
        return Result.failure('Annotation ID is required for update');
      }
      final db = await _databaseHelper.database;
      await db.update(
        _tableName,
        annotation.toMap(),
        where: 'id = ?',
        whereArgs: [annotation.id],
      );
      return Result.success(annotation);
    } catch (e) {
      return Result.failure('Failed to update annotation', e);
    }
  }

  @override
  Future<Result<void>> deleteAnnotation(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete annotation', e);
    }
  }

  @override
  Future<Result<void>> deleteAnnotationsForDocument(String documentPath) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        _tableName,
        where: 'document_path = ?',
        whereArgs: [documentPath],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete annotations for document', e);
    }
  }

  @override
  Future<Result<List<Annotation>>> getAnnotationsWithNotes(
      String documentPath) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        _tableName,
        where: 'document_path = ? AND note_text IS NOT NULL AND note_text != ?',
        whereArgs: [documentPath, ''],
        orderBy: 'page_number ASC, created_at ASC',
      );
      final annotations = maps.map((map) => Annotation.fromMap(map)).toList();
      return Result.success(annotations);
    } catch (e) {
      return Result.failure('Failed to get annotations with notes', e);
    }
  }
}
