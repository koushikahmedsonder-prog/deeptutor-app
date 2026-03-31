import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_theme.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/solver_screen.dart';
import 'screens/knowledge_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/question_gen_screen.dart';
import 'screens/research_screen.dart';
import 'screens/ideagen_screen.dart';
import 'screens/notebook_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/todo_screen.dart';
import 'services/document_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DeepTutorApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/solver',
      builder: (context, state) => const SolverScreen(),
    ),
    GoRoute(
      path: '/knowledge',
      builder: (context, state) => const KnowledgeScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) {
        final initialDoc = state.extra as PickedDocument?;
        return CameraScreen(initialDocument: initialDoc);
      },
    ),
    GoRoute(
      path: '/questions',
      builder: (context, state) => const QuestionGenScreen(),
    ),
    GoRoute(
      path: '/research',
      builder: (context, state) => const ResearchScreen(),
    ),
    GoRoute(
      path: '/ideagen',
      builder: (context, state) => const IdeagenScreen(),
    ),
    GoRoute(
      path: '/notebook',
      builder: (context, state) => const NotebookScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/todo',
      builder: (context, state) => const TodoScreen(),
    ),
  ],
);

class DeepTutorApp extends StatelessWidget {
  const DeepTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DeepTutor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
