import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import 'package:semob_dashboard/shared/widgets/page_components.dart';
import '../tool/preview_app.dart';

void main() {
  final destination = Platform.environment['SEMOB_CAPTURE_DIR'];
  testWidgets(
    'review the nine reported layouts with demo data and scrolled panels',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('NotoSans')
        ..addFont(rootBundle.load('backend/assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      const boundaryKey = Key('layout_review');
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: createPreviewApp()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_identifier')),
        previewEmail,
      );
      await tester.enterText(
        find.byKey(const Key('login_password')),
        previewPassword,
      );
      await tester.ensureVisible(find.byKey(const Key('login_submit')));
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      for (final entry in [
        ('/operation', 'operation-metrics', ''),
        ('/operation', 'operation-panels', 'Quilometragem por dia'),
        ('/fleet', 'fleet-metrics', ''),
        ('/passengers', 'passengers-panels', 'Evolução no período'),
        ('/financial', 'financial-metrics', ''),
        ('/insights', 'insights', ''),
        ('/assistant', 'assistant', ''),
        ('/users', 'users', ''),
        ('/profile', 'profile-panels', 'Informações do perfil'),
      ]) {
        container.read(routerProvider).go(entry.$1);
        await tester.pumpAndSettle();
        if (entry.$3.isNotEmpty) {
          await tester.ensureVisible(
            find.widgetWithText(SectionCard, entry.$3),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: entry.$2);
        if (entry.$1 == '/insights') {
          final left = tester.getRect(
            find.widgetWithText(SectionCard, 'Ambiente de demonstração'),
          );
          final right = tester.getRect(
            find.widgetWithText(SectionCard, 'Viagens de teste'),
          );
          expect(left.top, right.top);
          expect(left.height, right.height);
        }
        if (entry.$1 == '/users') {
          final first = tester.getRect(
            find.widgetWithText(ListTile, 'Administrador de demonstração'),
          );
          final second = tester.getRect(
            find.widgetWithText(ListTile, 'Operador de demonstração'),
          );
          expect(second.top - first.bottom, 16);
        }
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$destination/layout-demo-${entry.$2}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
    skip: destination == null,
  );
}
