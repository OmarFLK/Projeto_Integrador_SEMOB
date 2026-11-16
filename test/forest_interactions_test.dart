import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'test_support.dart';

Future<void> login(WidgetTester tester) async {
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
  testWidgets('administrator must confirm identity before approval', (
    tester,
  ) async {
    final adapter = TestHttpAdapter();
    await tester.pumpWidget(testApp(adapter: adapter));
    await login(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/access-requests');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Revisar e aprovar'));
    await tester.tap(find.text('Revisar e aprovar'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Aprovar e redefinir');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final approval = adapter.requests
        .where((r) => r.path.contains('/approve'))
        .single;
    expect((approval.data as Map)['identityVerified'], isTrue);
    expect(find.text('Nenhuma solicitação neste status.'), findsOneWidget);
  });

  testWidgets('charts expose exact point values through keyboard navigation', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await login(tester);
    final chart = find.byKey(const Key('keyboard_chart')).first;
    await tester.ensureVisible(chart);
    // Invoke the public focus handler through a real focus traversal request.
    Focus.of(
      tester.element(
        find
            .descendant(
              of: chart,
              matching: find.byKey(const Key('chart_semantics')),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final point = tester.widget<Semantics>(
      find.byKey(const Key('chart_semantics')).first,
    );
    expect(point.properties.value, startsWith('2 ·'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hover expands over content, pin persists, Escape and mouse exit collapse',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = TestHttpAdapter();
      await tester.pumpWidget(testApp(adapter: adapter));
      await login(tester);
      final sidebar = find.byKey(const Key('sidebar_width'));
      expect(tester.getSize(sidebar).width, 76);
      final oldContent = tester.getTopLeft(
        find.text('Uma cidade em movimento.'),
      );
      final requestCount = adapter.requests.length;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 0));
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('floating_sidebar'))),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 264);
      expect(
        tester.getTopLeft(find.text('Uma cidade em movimento.')),
        oldContent,
      );
      expect(
        adapter.requests.length,
        requestCount,
        reason: 'Hover não deve consultar a API novamente.',
      );
      await tester.tap(find.byKey(const Key('sidebar_pin')));
      await tester.pumpAndSettle();
      expect(adapter.preferences['sidebarPinned'], isTrue);
      await tester.tap(find.byKey(const Key('sidebar_pin')));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(800, 10));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 76);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'module tab is represented in URL and reveals actual indicators',
    (tester) async {
      await tester.pumpWidget(testApp());
      await login(tester);
      await tester.tap(find.byKey(const ValueKey('module_tab_indicators')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['view'],
        'indicators',
      );
      expect(find.text('Passageiros pagantes'), findsOneWidget);
      container.read(routerProvider).go('/dashboard?view=lines');
      await tester.pumpAndSettle();
      expect(find.text('As conexões da cidade'), findsOneWidget);
      expect(find.text('O pulso da cidade'), findsNothing);
    },
  );

  testWidgets(
    'manual recovery submits a proposal and shows protocol without claiming reset',
    (tester) async {
      final adapter = TestHttpAdapter();
      await tester.pumpWidget(testApp(adapter: adapter));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Esqueci minha senha'));
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recovery_name')),
        'Pessoa de teste',
      );
      await tester.enterText(
        find.byKey(const Key('recovery_identifier')),
        'person@example.org',
      );
      await tester.enterText(
        find.byKey(const Key('recovery_password')),
        'new-test-password-12345',
      );
      await tester.enterText(
        find.byKey(const Key('recovery_confirmation')),
        'new-test-password-12345',
      );
      await tester.ensureVisible(find.byKey(const Key('recovery_submit')));
      await tester.tap(find.byKey(const Key('recovery_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Solicitação registrada'), findsOneWidget);
      expect(find.text('test-recovery-protocol-12345'), findsOneWidget);
      expect(find.text('Senha redefinida'), findsNothing);
      final request = adapter.requests
          .where((r) => r.path.endsWith('password-recovery/manual'))
          .single;
      expect((request.data as Map)['identifier'], 'person@example.org');
      expect(find.byKey(const Key('recovery_password')), findsNothing);
    },
  );

  testWidgets('chart legend toggles series and expansion opens a real chart', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await login(tester);
    await tester.ensureVisible(
      find.byTooltip('Mostrar ou ocultar Catraca').first,
    );
    await tester.tap(find.byTooltip('Mostrar ou ocultar Catraca').first);
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('Catraca').first);
    expect(label.style?.decoration, TextDecoration.lineThrough);
    await tester.ensureVisible(find.byTooltip('Ampliar gráfico').first);
    await tester.tap(find.byTooltip('Ampliar gráfico').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fechar gráfico'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar gráfico'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
