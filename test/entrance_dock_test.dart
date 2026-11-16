import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'package:semob_dashboard/shared/widgets/page_components.dart';
import 'package:semob_dashboard/shared/widgets/viewport_entrance.dart';
import 'forest_interactions_test.dart' show login;
import 'test_support.dart';

void main() {
  testWidgets(
    'offscreen chart waits for visibility, replays only for new data',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Widget host(int data) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 200,
              width: 300,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(height: 450),
                    SizedBox(
                      height: 100,
                      width: 300,
                      child: ViewportEntrance(
                        lazy: true,
                        replayKey: data,
                        effect: EntranceEffect.draw,
                        child: const ColoredBox(
                          key: Key('expensive_chart'),
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('expensive_chart')),
        findsNothing,
        reason: 'Offscreen chart must not build or consume its animation.',
      );
      scroll.jumpTo(400);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('expensive_chart')), findsOneWidget);
      final clip = find
          .ancestor(
            of: find.byKey(const Key('expensive_chart')),
            matching: find.byWidgetPredicate(
              (w) => w is ClipRect && w.clipper != null,
            ),
          )
          .first;
      expect(
        tester
            .widget<ClipRect>(clip)
            .clipper!
            .getClip(const Size(300, 100))
            .width,
        lessThan(40),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(host(1));
      expect(
        find.ancestor(
          of: find.byKey(const Key('expensive_chart')),
          matching: find.byWidgetPredicate(
            (w) => w is ClipRect && w.clipper != null,
          ),
        ),
        findsNothing,
        reason: 'Ordinary rebuild must keep a finished chart visible.',
      );
      await tester.pumpWidget(host(2));
      await tester.pump();
      expect(
        find.ancestor(
          of: find.byKey(const Key('expensive_chart')),
          matching: find.byWidgetPredicate(
            (w) => w is ClipRect && w.clipper != null,
          ),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reduced motion displays the complete chart immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(
            height: 100,
            child: ViewportEntrance(lazy: true, child: Text('Dados completos')),
          ),
        ),
      ),
    );
    expect(find.text('Dados completos'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'dock stays centered over scrolling content and navigates account URLs',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = TestHttpAdapter();
      await tester.pumpWidget(testApp(adapter: adapter));
      await login(tester);
      final dock = find.byKey(const Key('floating_context_dock'));
      final before = tester.getCenter(dock);
      expect(before.dx, closeTo((1440 + 92) / 2, 1));
      expect(before.dy, greaterThan(850));
      final requests = adapter.requests.length;
      await tester.drag(find.byType(PageBody), const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(tester.getCenter(dock), before);
      expect(adapter.requests.length, requests);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      final chat = find.byKey(const ValueKey('dock_/settings?tab=chat'));
      await tester.ensureVisible(chat);
      await tester.tap(chat);
      await tester.pumpAndSettle();
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['tab'],
        'chat',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
