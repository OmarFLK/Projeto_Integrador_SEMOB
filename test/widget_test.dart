import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/app.dart';
import 'package:semob_dashboard/shared/widgets/page_components.dart';

void main() {
  testWidgets('exibe login institucional e credenciais de demonstração', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SemobApp()));
    await tester.pumpAndSettle();

    expect(find.text('Portal de Operação\nde Transporte'), findsOneWidget);
    expect(find.byKey(const Key('login_identifier')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('login válido abre a visão geral', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SemobApp()));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('login_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Visão Geral'), findsWidgets);
    expect(find.text('Passageiros totais'), findsOneWidget);
  });

  testWidgets('grade de indicadores se adapta a largura mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricsGrid(
            children: [
              MetricCard(label: 'A', value: '1', icon: Icons.route),
              MetricCard(label: 'B', value: '2', icon: Icons.route),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MetricCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (name: 'mobile', size: Size(390, 844)),
    (name: 'tablet', size: Size(900, 1100)),
    (name: 'desktop', size: Size(1440, 900)),
  ]) {
    testWidgets('dashboard sem overflow em ${viewport.name}', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: SemobApp()));
      await tester.pumpAndSettle();

      final submit = find.byKey(const Key('login_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Passageiros totais'), findsOneWidget);
      final exception = tester.takeException();
      if (exception is FlutterError) {
        debugPrint(exception.toStringDeep());
      }
      expect(exception, isNull);
    });
  }
}
