import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'package:semob_dashboard/shared/providers/app_providers.dart';
import 'test_support.dart';

/// Explicitly opt in: SEMOB_CAPTURE_DIR=.dart_tool/visual-review.
/// All records in these images come from test fixtures, never production.
void main() {
  final destination = Platform.environment['SEMOB_CAPTURE_DIR'];
  testWidgets(
    'capture all routes and responsive Forest themes with test fixtures',
    (tester) async {
      final font = FontLoader('NotoSans')
        ..addFont(rootBundle.load('backend/assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory(destination!);
      directory.createSync(recursive: true);
      const boundaryKey = ValueKey('visual_boundary');
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        debugPrint('Rendering $name');
        expect(tester.takeException(), isNull, reason: name);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${directory.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final size in [
        const Size(390, 844),
        const Size(768, 1024),
        const Size(1440, 1000),
        const Size(1920, 1080),
      ]) {
        tester.view.physicalSize = size;
        final adapter = TestHttpAdapter()..preferences['theme'] = 'dark';
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: testApp(adapter: adapter),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          await precacheImage(
            const AssetImage('assets/images/semob_logo.png'),
            context,
          );
          await precacheImage(
            const AssetImage('assets/images/login_bus.png'),
            context,
          );
        });
        await capture('login-${size.width.toInt()}');
        await tester.enterText(
          find.byKey(const Key('login_identifier')),
          'admin@example.org',
        );
        await tester.enterText(
          find.byKey(const Key('login_password')),
          'semob2026',
        );
        await tester.ensureVisible(find.byKey(const Key('login_submit')));
        await tester.tap(find.byKey(const Key('login_submit')));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final paths = size.width == 1920
            ? ['/dashboard']
            : [
                '/dashboard',
                '/operation',
                '/trips',
                '/passengers',
                '/lines',
                '/fleet',
                '/financial',
                '/anomalies',
                '/insights',
                '/assistant',
                '/reports',
                '/users',
                '/access-requests',
                '/profile',
                '/settings',
                '/help',
                '/lines/03',
                '/fleet/1769',
              ];
        for (final path in paths) {
          container.read(routerProvider).go(path);
          await capture(
            '${path.substring(1).replaceAll('/', '-')}-${size.width.toInt()}-dark',
          );
        }
        if (size.width == 1440) {
          unawaited(
            container.read(preferencesProvider.notifier).save({
              'sidebarPinned': true,
            }),
          );
          await tester.pumpAndSettle();
          container.read(routerProvider).go('/dashboard');
          await capture('sidebar-expanded-desktop');
          unawaited(
            container.read(preferencesProvider.notifier).save({
              'sidebarPinned': false,
              'theme': 'light',
            }),
          );
          await tester.pumpAndSettle();
          for (final path in paths) {
            container.read(routerProvider).go(path);
            await capture(
              '${path.substring(1).replaceAll('/', '-')}-1440-light',
            );
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    skip: destination == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
