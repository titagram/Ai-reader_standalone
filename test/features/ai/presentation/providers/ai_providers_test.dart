import 'package:flutter_test/flutter_test.dart';

import 'package:ai_reader/features/ai/domain/entities/model_info.dart';
import 'package:ai_reader/features/ai/presentation/providers/ai_providers.dart';

import '../../mocks/mock_ai_model_repository.dart';

void main() {
  // --------------- ModelStateNotifier Tests ---------------
  group('ModelStateNotifier', () {
    late MockAiModelRepository mockRepo;
    late ModelStateNotifier notifier;

    setUp(() {
      mockRepo = MockAiModelRepository();
      notifier = ModelStateNotifier(mockRepo);
    });

    test('initial state has no model and is not loading', () {
      final state = notifier.debugState;
      expect(state.currentModel, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isDownloading, isFalse);
      expect(state.error, isNull);
    });

    test('checkModelStatus sets notDownloaded when model is absent', () async {
      mockRepo.shouldReportNotDownloaded = true;

      await notifier.checkModelStatus();

      final state = notifier.debugState;
      expect(state.currentModel, isNotNull);
      expect(state.currentModel!.status, ModelStatus.notDownloaded);
      expect(mockRepo.isModelDownloadedCallCount, 1);
    });

    test('checkModelStatus sets downloaded when model is present', () async {
      mockRepo.shouldReportNotDownloaded = false;

      await notifier.checkModelStatus();

      final state = notifier.debugState;
      expect(state.currentModel, isNotNull);
      expect(state.currentModel!.status, ModelStatus.downloaded);
      expect(mockRepo.isModelDownloadedCallCount, 1);
    });

    test('downloadModel updates progress and completes', () async {
      await notifier.downloadModel();

      final state = notifier.debugState;
      expect(state.isDownloading, isFalse);
      expect(state.downloadProgress, 1.0);
      expect(state.currentModel, isNotNull);
      expect(state.currentModel!.status, ModelStatus.downloaded);
      expect(state.error, isNull);
      expect(mockRepo.downloadModelCallCount, 1);
    });

    test('downloadModel sets error on failure', () async {
      mockRepo.shouldFailDownload = true;

      await notifier.downloadModel();

      final state = notifier.debugState;
      expect(state.isDownloading, isFalse);
      expect(state.error, isNotNull);
      expect(state.currentModel!.status, ModelStatus.error);
      expect(mockRepo.downloadModelCallCount, 1);
    });

    test('loadModel transitions to loaded state', () async {
      // First make the model appear downloaded
      mockRepo.shouldReportNotDownloaded = false;
      await notifier.checkModelStatus();

      await notifier.loadModel();

      final state = notifier.debugState;
      expect(state.isLoading, isFalse);
      expect(state.currentModel!.status, ModelStatus.loaded);
      expect(state.error, isNull);
      expect(mockRepo.loadModelCallCount, 1);
    });

    test('loadModel fails when not downloaded', () async {
      // Model is null initially, so loadModel should fail
      await notifier.loadModel();

      final state = notifier.debugState;
      expect(state.error, 'Model not downloaded');
      expect(mockRepo.loadModelCallCount, 0);
    });

    test('loadModel fails when model file path is not found', () async {
      // Set model as downloaded but path returns null
      mockRepo.shouldReportNotDownloaded = false;
      await notifier.checkModelStatus();

      // Now make getLocalModelPath return null
      mockRepo.shouldReportNotDownloaded = true;

      await notifier.loadModel();

      final state = notifier.debugState;
      expect(state.isLoading, isFalse);
      expect(state.error, 'Model file not found');
    });

    test('unloadModel transitions back to downloaded', () async {
      // Setup: downloaded and loaded
      mockRepo.shouldReportNotDownloaded = false;
      await notifier.checkModelStatus();
      await notifier.loadModel();
      expect(notifier.debugState.currentModel!.status, ModelStatus.loaded);

      await notifier.unloadModel();

      final state = notifier.debugState;
      expect(state.currentModel!.status, ModelStatus.downloaded);
      expect(mockRepo.unloadModelCallCount, 1);
    });
  });

  // --------------- SummarizationNotifier Tests ---------------
  group('SummarizationNotifier', () {
    late MockAiModelRepository mockRepo;
    late SummarizationNotifier notifier;

    setUp(() {
      mockRepo = MockAiModelRepository();
      notifier = SummarizationNotifier(mockRepo);
    });

    test('initial state is not generating and has no summary', () {
      final state = notifier.debugState;
      expect(state.isGenerating, isFalse);
      expect(state.summary, isNull);
      expect(state.error, isNull);
      expect(state.progress, 0.0);
    });

    test('generateSummary produces result', () async {
      mockRepo.generateResult = 'This is the mock summary.';

      await notifier.generateSummary('Some long text to summarize.');

      final state = notifier.debugState;
      expect(state.isGenerating, isFalse);
      expect(state.summary, 'This is the mock summary.');
      expect(state.error, isNull);
      expect(state.progress, 1.0);
      expect(mockRepo.generateSummaryCallCount, 1);
    });

    test('generateSummary sets error on failure', () async {
      mockRepo.shouldFailGenerate = true;

      await notifier.generateSummary('Some text.');

      final state = notifier.debugState;
      expect(state.isGenerating, isFalse);
      expect(state.error, isNotNull);
      expect(state.summary, isNull);
      expect(mockRepo.generateSummaryCallCount, 1);
    });

    test('clear resets state', () async {
      // Generate a summary first
      await notifier.generateSummary('Some text.');
      expect(notifier.debugState.summary, isNotNull);

      notifier.clear();

      final state = notifier.debugState;
      expect(state.isGenerating, isFalse);
      expect(state.summary, isNull);
      expect(state.error, isNull);
      expect(state.progress, 0.0);
    });
  });
}
