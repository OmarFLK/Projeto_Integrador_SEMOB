import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'package:semob_dashboard/shared/widgets/page_components.dart';
import 'test_support.dart';
import 'screens_test.dart' show signIn;

void main() {
  testWidgets('fleet metrics fit the tablet breakpoint', (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await signIn(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/fleet');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'all metric cards have equal heights, including wrapping helpers and large text',
    (tester) async {
      for (final width in [390.0, 900.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
                  child: MetricsGrid(
                    children: [
                      for (var i = 0; i < 8; i++)
                        MetricCard(
                          label: i.isEven
                              ? 'Veículos em operação'
                              : 'Quilometragem improdutiva registrada',
                          value: i == 3 ? 'Histórico' : '1.513,7 km',
                          icon: Icons.bus_alert,
                          helper: i.isEven
                              ? 'Um texto auxiliar longo que precisa quebrar em várias linhas.'
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byType(MetricCard);
        final heights = [
          for (final element in cards.evaluate())
            tester.getSize(find.byWidget(element.widget)).height,
        ];
        expect(
          heights.every((h) => (h - heights.first).abs() < .1),
          isTrue,
          reason: '$width',
        );
        expect(tester.takeException(), isNull, reason: '$width');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'paired panels and profile align, insights and assistant use full width',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
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
        '/financial',
        '/profile',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        for (final grid in find.byType(EqualHeightGrid).evaluate()) {
          final widget = grid.widget as EqualHeightGrid;
          final cells = [
            for (final child in widget.children)
              tester.getSize(find.byWidget(child)),
          ];
          expect(
            cells.every((s) => (s.height - cells.first.height).abs() < .1),
            isTrue,
            reason: path,
          );
        }
        expect(tester.takeException(), isNull, reason: path);
      }
      container.read(routerProvider).go('/insights');
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SemobHeroPanel)).width,
        tester.getSize(find.byType(SectionCard).first).width * 2 + 16,
      );
      container.read(routerProvider).go('/assistant');
      await tester.pumpAndSettle();
      final hero = tester.getRect(find.byType(SemobHeroPanel));
      final input = tester.getRect(
        find
            .descendant(
              of: find.byKey(const Key('assistant_composer')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(hero.left, input.left);
      expect(hero.right, input.right);
      expect(
        input.bottom,
        lessThan(
          tester.getRect(find.byKey(const Key('floating_context_dock'))).top,
        ),
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('assistant_input')),
      );
      expect(
        (field.decoration!.disabledBorder as OutlineInputBorder).borderRadius,
        BorderRadius.circular(24),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
