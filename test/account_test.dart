import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/features/auth/presentation/auth_controller.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'screens_test.dart' show signIn;
import 'test_support.dart';

void main() {
  testWidgets('profile save updates header without leaving the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = TestHttpAdapter();
    await tester.pumpWidget(testApp(adapter: adapter));
    await signIn(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final router = container.read(routerProvider);
    router.go('/profile');
    await tester.pumpAndSettle();
    final name = find.byType(TextFormField).first;
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Maria Operação');
    final save = find.text('Salvar alterações');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(adapter.profile['name'], 'Maria Operação');
    expect(container.read(authProvider).user!.name, 'Maria Operação');
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(tester.takeException(), null);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'dark preferences persist and every account section fits at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final adapter = TestHttpAdapter();
        await tester.pumpWidget(testApp(adapter: adapter));
        await signIn(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final router = container.read(routerProvider);
        router.go('/settings');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Escuro'));
        await tester.tap(find.text('Escuro'));
        await tester.pumpAndSettle();
        expect(adapter.preferences['theme'], 'dark');
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
        for (final tab in ['chat', 'ai', 'memory', 'privacy']) {
          router.go('/settings?tab=$tab');
          await tester.pumpAndSettle();
          expect(tester.takeException(), null, reason: tab);
        }
        router.go('/profile');
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
      },
    );
  }
}
