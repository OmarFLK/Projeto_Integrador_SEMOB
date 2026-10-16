import 'dart:io';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/dataset_importer.dart';
import 'package:semob_backend/data_service.dart';
import 'package:test/test.dart';

void main() {
  final address = Platform.environment['SEMOB_TEST_MONGODB_URI'];
  test(
    'real MongoDB imports, queries and rejects concurrent publication',
    () async {
      final uri = Uri.parse(
        address!,
      ).replace(path: '/semob_test_${DateTime.now().microsecondsSinceEpoch}');
      final store = await MongoDocumentStore.open(uri.toString());
      try {
        final importer = DatasetImporter(store);
        final parsed = importer.parseCsv(
          'date,turnstile,advance_sales,non_paying,total\n2026-08-01,10,20,30,60\n',
          'passenger_days',
          'synthetic.csv',
        );
        await importer.import(parsed);
        final gen = await store.generation();
        final service = DataService(store);
        expect((await store.manifest())['counts']['passenger_days'], 1);
        expect(
          (await service.resource('passengers', {
            'period': '2026-08',
          })).single['total'],
          60,
        );
        await expectLater(
          store.publish('stale', 'rejected', [], {}),
          throwsStateError,
        );
        expect(await store.generation(), gen);
        expect(await store.read('rejected', 'passenger_days'), isEmpty);
        // Dashboard requests must share a healthy connection on Atlas.
        for (var wave = 0; wave < 3; wave++) {
          final results = await Future.wait([
            service.options({'period': '2026-08'}),
            service.coverage({'period': '2026-08'}),
            service.resource('passengers', {'period': '2026-08'}),
            store.manifest(),
          ]);
          expect((results[0] as Document)['lines'], isEmpty);
          expect((results[2] as List).single['total'], 60);
        }
        await store.db.close();
        final recovered = await Future.wait([
          store.generation(),
          store.read(gen, 'passenger_days', period: '2026-08'),
          store.manifest(),
        ]);
        expect(recovered[0], gen);
        expect((recovered[1] as List).single['total'], 60);
        expect(await store.ready(), isTrue);
      } finally {
        await store.db.drop();
        await store.close();
      }
    },
    skip: address == null
        ? 'Configure SEMOB_TEST_MONGODB_URI para executar contra MongoDB real.'
        : false,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
