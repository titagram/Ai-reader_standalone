import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_locator.dart';
import '../../../storage/data/repositories/annotation_repository_impl.dart';
import '../../../storage/domain/entities/annotation.dart';
import '../../../storage/domain/repositories/annotation_repository.dart';

/// Provider for annotation repository
final annotationRepositoryProvider = Provider<AnnotationRepository>((ref) {
  return AnnotationRepositoryImpl(
    databaseHelper: ServiceLocator.instance.databaseHelper,
  );
});

/// State for document annotations
class AnnotationsState {
  const AnnotationsState({
    this.annotations = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Annotation> annotations;
  final bool isLoading;
  final String? error;

  AnnotationsState copyWith({
    List<Annotation>? annotations,
    bool? isLoading,
    String? error,
  }) {
    return AnnotationsState(
      annotations: annotations ?? this.annotations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing document annotations
class AnnotationsNotifier extends StateNotifier<AnnotationsState> {
  AnnotationsNotifier(this._repository) : super(const AnnotationsState());

  final AnnotationRepository _repository;
  String? _currentDocumentPath;

  /// Load annotations for a document
  Future<void> loadAnnotations(String documentPath) async {
    _currentDocumentPath = documentPath;
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getAnnotationsForDocument(documentPath);

    result.fold(
      onSuccess: (annotations) {
        state = state.copyWith(
          annotations: annotations,
          isLoading: false,
        );
      },
      onFailure: (message, error) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  /// Add a new annotation
  Future<void> addAnnotation(Annotation annotation) async {
    final result = await _repository.saveAnnotation(annotation);

    result.fold(
      onSuccess: (saved) {
        state = state.copyWith(
          annotations: [...state.annotations, saved],
        );
      },
      onFailure: (message, error) {
        state = state.copyWith(error: message);
      },
    );
  }

  /// Update an existing annotation
  Future<void> updateAnnotation(Annotation annotation) async {
    final result = await _repository.updateAnnotation(annotation);

    result.fold(
      onSuccess: (updated) {
        final annotations = state.annotations.map((a) {
          return a.id == updated.id ? updated : a;
        }).toList();
        state = state.copyWith(annotations: annotations);
      },
      onFailure: (message, error) {
        state = state.copyWith(error: message);
      },
    );
  }

  /// Delete an annotation
  Future<void> deleteAnnotation(int id) async {
    final result = await _repository.deleteAnnotation(id);

    result.fold(
      onSuccess: (_) {
        final annotations =
            state.annotations.where((a) => a.id != id).toList();
        state = state.copyWith(annotations: annotations);
      },
      onFailure: (message, error) {
        state = state.copyWith(error: message);
      },
    );
  }

  /// Get annotations for a specific page
  List<Annotation> getAnnotationsForPage(int pageNumber) {
    return state.annotations
        .where((a) => a.pageNumber == pageNumber)
        .toList();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for annotations state
final annotationsProvider =
    StateNotifierProvider<AnnotationsNotifier, AnnotationsState>((ref) {
  final repository = ref.watch(annotationRepositoryProvider);
  return AnnotationsNotifier(repository);
});

/// Provider for current reading position
final currentPageProvider = StateProvider<int>((ref) => 1);

/// Provider for total pages
final totalPagesProvider = StateProvider<int>((ref) => 0);
