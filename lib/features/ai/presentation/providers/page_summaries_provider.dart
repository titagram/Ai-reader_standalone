import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/page_summaries_repository.dart';
import '../../domain/entities/page_summary.dart';

/// Provider for page summaries repository
final pageSummariesRepositoryProvider = Provider<PageSummariesRepository>((ref) {
  return PageSummariesRepository();
});

/// State for page summary generation
class PageSummaryGenerationState {
  const PageSummaryGenerationState({
    this.isGenerating = false,
    this.generatingUnitNumber,
    this.error,
  });

  final bool isGenerating;
  final int? generatingUnitNumber;
  final String? error;

  PageSummaryGenerationState copyWith({
    bool? isGenerating,
    int? generatingUnitNumber,
    String? error,
  }) {
    return PageSummaryGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatingUnitNumber: generatingUnitNumber,
      error: error,
    );
  }
}

/// Provider for generation state
final pageSummaryGenerationStateProvider =
    StateProvider<PageSummaryGenerationState>(
        (ref) => const PageSummaryGenerationState(),);

/// Provider for summaries of a specific document (cached)
final documentSummariesProvider =
    FutureProvider.family<Map<int, PageSummary>, String>((ref, documentPath) async {
  final repository = ref.watch(pageSummariesRepositoryProvider);
  return repository.getSummariesForDocument(documentPath);
});

/// Provider to check if a specific unit has a summary
final hasPageSummaryProvider =
    Provider.family<bool, ({String documentPath, int unitNumber})>((ref, params) {
  final summariesAsync = ref.watch(documentSummariesProvider(params.documentPath));
  return summariesAsync.maybeWhen(
    data: (summaries) => summaries.containsKey(params.unitNumber),
    orElse: () => false,
  );
});

/// Provider to get a specific summary
final pageSummaryProvider =
    Provider.family<PageSummary?, ({String documentPath, int unitNumber})>((ref, params) {
  final summariesAsync = ref.watch(documentSummariesProvider(params.documentPath));
  return summariesAsync.maybeWhen(
    data: (summaries) => summaries[params.unitNumber],
    orElse: () => null,
  );
});
