import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_dashboard/shared/widgets/page_components.dart';
import 'test_support.dart';

Widget _testApp() => testApp();

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login_identifier')),
    'admin@semob.sp.gov.br',
  );
  await tester.enterText(find.byKey(const Key('login_password')), 'semob2026');
  final submit = find.byKey(const Key('login_submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exibe o login institucional', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Portal de Operação\nde Transporte'), findsOneWidget);
    expect(find.byKey(const Key('login_identifier')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('login válido abre a visão geral', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await _signIn(tester);

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

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      await _signIn(tester);

      expect(find.text('Passageiros totais'), findsOneWidget);
      final exception = tester.takeException();
      if (exception is FlutterError) {
        debugPrint(exception.toStringDeep());
      }
      expect(exception, isNull);
    });
  }
}
