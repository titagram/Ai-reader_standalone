import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/summary/presentation/screens/summary_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.homeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.reader,
        name: Routes.readerName,
        builder: (context, state) {
          final filePath = state.extra as String?;
          return ReaderScreen(filePath: filePath ?? '');
        },
      ),
      GoRoute(
        path: Routes.summary,
        name: Routes.summaryName,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SummaryScreen(
            summaryText: extra?['summaryText'] as String? ?? '',
            documentName: extra?['documentName'] as String? ?? '',
            summaryId: extra?['summaryId'] as int?,
          );
        },
      ),
      GoRoute(
        path: Routes.history,
        name: Routes.historyName,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        name: Routes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
  );
});
