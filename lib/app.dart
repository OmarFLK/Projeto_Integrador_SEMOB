import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'shared/providers/app_providers.dart';

class SemobApp extends ConsumerWidget {
  const SemobApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
    final prefs = signedIn ? ref.watch(preferencesProvider).value : null;
    final compact = prefs?['compact'] == true;
    return MaterialApp.router(
      title: 'SEMOB | Portal de Operação',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, compact: compact),
      darkTheme: AppTheme.build(Brightness.dark, compact: compact),
      themeMode: switch (prefs?['theme']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
