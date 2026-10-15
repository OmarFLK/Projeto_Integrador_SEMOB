import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'package:semob_dashboard/shared/providers/app_providers.dart';
import 'test_support.dart';

Future<void> signIn(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('login_identifier')),
    'admin@example.org',
  );
  await tester.enterText(find.byKey(const Key('login_password')), 'semob2026');
  await tester.ensureVisible(find.byKey(const Key('login_submit')));
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(900, 1100),
    const Size(1440, 900),
  ]) {
    testWidgets('all pages load without overflow at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp());
      await signIn(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      for (final path in [
        '/operation',
        '/passengers',
        '/lines',
        '/fleet',
        '/financial',
        '/anomalies',
        '/insights',
        '/assistant',
        '/reports',
        '/users',
        '/profile',
        '/settings',
        '/help',
        '/trips',
        '/lines/03',
        '/fleet/1769',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        final error = tester.takeException();
        expect(error, isNull, reason: path);
      }
    });
  }
  testWidgets('trips next page and global filters are sent to API', (
    tester,
  ) async {
    final adapter = TestHttpAdapter();
    await tester.pumpWidget(testApp(adapter: adapter));
    await signIn(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/trips');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Próxima'));
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(adapter.queries['trips']?['offset'], '50');
    final filters = container.read(globalFiltersProvider);
    container
        .read(globalFiltersProvider.notifier)
        .update(
          filters.copyWith(
            line: '03',
            vehicle: '1769',
            direction: 'Ida',
            timeRange: '04h–05h',
          ),
        );
    await tester.pumpAndSettle();
    expect(adapter.queries['trips']?['offset'], '0');
    expect(adapter.queries['trips']?['line'], '03');
    expect(adapter.queries['trips']?['vehicle'], '1769');
    expect(adapter.queries['trips']?['direction'], 'Ida');
    expect(adapter.queries['trips']?['timeRange'], '04h–05h');
  });
  testWidgets('operator cannot open users, financial or assistant', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(role: 'operator'));
    await signIn(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    for (final path in ['/users', '/financial', '/assistant']) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(find.text('Visão Geral'), findsWidgets);
    }
  });
}
