import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/router/app_router.dart';
import '../tool/preview_app.dart';

void main() {
  test(
    'preview rejects unknown writes and filters/pages its in-memory trips',
    () async {
      final dio = Dio(
        BaseOptions(baseUrl: 'http://semob-preview.invalid/api/v1/'),
      )..httpClientAdapter = PreviewAdapter();
      await expectLater(
        dio.get<dynamic>('operation'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.post<dynamic>(
          'auth/login',
          data: {'identifier': previewEmail, 'password': 'wrong'},
        ),
        throwsA(isA<DioException>()),
      );
      await dio.post<dynamic>(
        'auth/login',
        data: {'identifier': previewEmail, 'password': previewPassword},
      );
      final trips = (await dio.get<Map<String, dynamic>>(
        'trips',
        queryParameters: {'line': '03', 'offset': '50', 'limit': '10'},
      )).data!;
      expect(trips['total'], greaterThan(50));
      expect((trips['items'] as List).length, 10);
      expect((trips['items'] as List).every((r) => r['line'] == '03'), isTrue);
      await expectLater(
        dio.post<dynamic>('imports', data: {'content': 'dummy'}),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            501,
          ),
        ),
      );
      await dio.put<dynamic>('preferences', data: {'theme': 'light'});
      expect(
        (await dio.get<Map<String, dynamic>>('preferences')).data!['theme'],
        'light',
      );
      expect(
        jsonEncode((await dio.get<dynamic>('insights')).data),
        contains('sintéticos'),
      );
      dio.close();
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets('database-free preview opens every screen at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(createPreviewApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('DEMONSTRAÇÃO LOCAL'), findsOneWidget);
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
      expect(find.text('Passageiros totais'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      for (final path in [
        '/operation',
        '/trips',
        '/passengers',
        '/lines',
        '/lines/03',
        '/fleet',
        '/fleet/1501',
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
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
        expect(
          find.text('Não foi possível carregar os dados.'),
          findsNothing,
          reason: path,
        );
      }
    });
  }
}
