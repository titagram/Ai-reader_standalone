import '../../../../core/utils/result.dart';
import '../entities/annotation.dart';

/// Repository interface for annotation operations
abstract class AnnotationRepository {
  /// Get all annotations for a document
  Future<Result<List<Annotation>>> getAnnotationsForDocument(
      String documentPath);

  /// Get annotations for a specific page
  Future<Result<List<Annotation>>> getAnnotationsForPage(
    String documentPath,
    int pageNumber,
  );

  /// Get an annotation by ID
  Future<Result<Annotation>> getAnnotationById(int id);

  /// Save a new annotation
  Future<Result<Annotation>> saveAnnotation(Annotation annotation);

  /// Update an existing annotation
  Future<Result<Annotation>> updateAnnotation(Annotation annotation);

  /// Delete an annotation
  Future<Result<void>> deleteAnnotation(int id);

  /// Delete all annotations for a document
  Future<Result<void>> deleteAnnotationsForDocument(String documentPath);

  /// Get annotations with notes only
  Future<Result<List<Annotation>>> getAnnotationsWithNotes(String documentPath);
}
