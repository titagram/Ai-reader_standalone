import '../../../../core/utils/result.dart';
import '../entities/summary.dart';

/// Repository interface for summary operations
abstract class SummaryRepository {
  /// Get all summaries
  Future<Result<List<Summary>>> getAllSummaries();

  /// Get summaries for a specific document
  Future<Result<List<Summary>>> getSummariesForDocument(String documentPath);

  /// Get a summary by ID
  Future<Result<Summary>> getSummaryById(int id);

  /// Save a new summary
  Future<Result<Summary>> saveSummary(Summary summary);

  /// Update an existing summary
  Future<Result<Summary>> updateSummary(Summary summary);

  /// Delete a summary
  Future<Result<void>> deleteSummary(int id);

  /// Delete all summaries for a document
  Future<Result<void>> deleteSummariesForDocument(String documentPath);

  /// Search summaries by text
  Future<Result<List<Summary>>> searchSummaries(String query);
}
