import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' hide UnitType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/domain/entities/page_summary.dart';
import '../../../ai/presentation/widgets/page_summary_overlay.dart';

/// EPUB viewer widget
class EpubViewer extends ConsumerStatefulWidget {
  const EpubViewer({
    super.key,
    required this.filePath,
    this.onPageChanged,
  });

  final String filePath;
  final void Function(int current, int total)? onPageChanged;

  @override
  ConsumerState<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends ConsumerState<EpubViewer> {
  EpubBook? _book;
  List<EpubChapter> _chapters = [];
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  Future<void> _loadEpub() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      setState(() {
        _book = book;
        _chapters = _flattenChapters(book.Chapters ?? []);
        _isLoading = false;
      });

      widget.onPageChanged?.call(1, _chapters.length);
    } catch (e) {
      setState(() {
        _error = 'Failed to load EPUB: $e';
        _isLoading = false;
      });
    }
  }

  /// Flatten nested chapters into a single list
  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final chapter in chapters) {
      result.add(chapter);
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        result.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return result;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return const Center(
        child: Text('No content found in this EPUB'),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Chapter navigation
            _ChapterNavigator(
              chapters: _chapters,
              currentIndex: _currentChapterIndex,
              onChapterSelected: (index) {
                _pageController.jumpToPage(index);
              },
            ),
            // Chapter content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _chapters.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentChapterIndex = index;
                  });
                  widget.onPageChanged?.call(index + 1, _chapters.length);
                },
                itemBuilder: (context, index) {
                  return _ChapterContent(chapter: _chapters[index]);
                },
              ),
            ),
          ],
        ),
        // Chapter summary overlay (uses chapter index + 1 as unit number)
        PageSummaryOverlay(
          documentPath: widget.filePath,
          currentPage: _currentChapterIndex + 1,
          totalPages: _chapters.length,
          unitType: UnitType.chapter,
        ),
      ],
    );
  }
}

/// Chapter navigation dropdown
class _ChapterNavigator extends StatelessWidget {
  const _ChapterNavigator({
    required this.chapters,
    required this.currentIndex,
    required this.onChapterSelected,
  });

  final List<EpubChapter> chapters;
  final int currentIndex;
  final void Function(int index) onChapterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentIndex > 0
                ? () => onChapterSelected(currentIndex - 1)
                : null,
          ),
          Expanded(
            child: DropdownButton<int>(
              value: currentIndex,
              isExpanded: true,
              underline: const SizedBox(),
              items: chapters.asMap().entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value.Title ?? 'Chapter ${entry.key + 1}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (index) {
                if (index != null) {
                  onChapterSelected(index);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentIndex < chapters.length - 1
                ? () => onChapterSelected(currentIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Chapter content widget
class _ChapterContent extends StatelessWidget {
  const _ChapterContent({required this.chapter});

  final EpubChapter chapter;

  @override
  Widget build(BuildContext context) {
    final content = chapter.HtmlContent ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.Title != null) ...[
            Text(
              chapter.Title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
          ],
          Html(
            data: content,
            style: {
              'body': Style(
                fontSize: FontSize(16),
                lineHeight: LineHeight(1.6),
              ),
              'p': Style(
                margin: Margins.only(bottom: 12),
              ),
              'h1': Style(
                fontSize: FontSize(24),
                fontWeight: FontWeight.bold,
              ),
              'h2': Style(
                fontSize: FontSize(20),
                fontWeight: FontWeight.bold,
              ),
              'h3': Style(
                fontSize: FontSize(18),
                fontWeight: FontWeight.bold,
              ),
            },
          ),
        ],
      ),
    );
  }
}
