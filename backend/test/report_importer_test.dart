import 'dart:io';
import 'dart:convert';
import 'package:semob_backend/dataset_importer.dart';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/data_service.dart';
import 'package:semob_backend/csv_codec.dart';
import 'package:test/test.dart';
import 'package:semob_backend/backup.dart';
import 'package:archive/archive.dart';
import 'package:semob_backend/errors.dart';

void main() {
  final privateArchive = File(
    Platform.environment['SEMOB_TEST_DATA_ARCHIVE'] ??
        'data/semob_transport_reports.zip',
  );
  test('synthetic HTML ZIP imports without private production reports', () async {
    final temporary = Directory.systemTemp.createTempSync('semob-html-test-');
    final store = await LocalDocumentStore.open(
      '${temporary.path}/docs.sembast',
    );
    try {
      const html =
          '<table class="data"><tr><th>Data</th><th>Dia Sem</th><th>Nr Veiculos</th><th>Nr Max Veic Fx</th><th>Nr Viagens Progr</th><th>Nr Viagens Realiz</th><th>Km Prod</th><th>Km Improd</th><th>Km Total</th></tr><tr><td>01/08/2026</td><td>Sab</td><td>1</td><td>1</td><td>10</td><td>9</td><td>100</td><td>2</td><td>102</td></tr></table>';
      final bytes = ZipEncoder().encode(
        Archive()..addFile(
          ArchiveFile.string('Agosto_2026/Mensal/operation.html', html),
        ),
      );
      final importer = DatasetImporter(store);
      final parsed = importer.parseArchive(bytes);
      expect(parsed.rawFiles, hasLength(1));
      expect(
        parsed.rows
            .where((row) => row['table'] == 'operation_days')
            .single['scheduled_trips'],
        10,
      );
      await importer.import(parsed);
      expect(
        (await DataService(store).resource('operation', {
          'period': '2026-08',
        })).single['completedTrips'],
        9,
      );
    } finally {
      await store.close();
      temporary.deleteSync(recursive: true);
    }
  });
  test(
    'ZIP rejects traversal paths and forged oversized entries before processing HTML',
    () async {
      final temporary = Directory.systemTemp.createTempSync('semob-zip-test-');
      final store = await LocalDocumentStore.open(
        '${temporary.path}/docs.sembast',
      );
      try {
        final importer = DatasetImporter(store);
        final unsafe = ZipEncoder().encode(
          Archive()..addFile(
            ArchiveFile.string('../Agosto_2026/Mensal/test.html', 'test'),
          ),
        );
        expect(() => importer.parseArchive(unsafe), throwsA(isA<ApiError>()));
        final forged = ZipEncoder().encode(
          Archive()..addFile(
            ArchiveFile.string('Agosto_2026/Mensal/test.html', 'test'),
          ),
        );
        for (var i = 0; i < forged.length - 28; i++) {
          if (forged[i] == 0x50 &&
              forged[i + 1] == 0x4b &&
              forged[i + 2] == 0x01 &&
              forged[i + 3] == 0x02) {
            // Central directory advertises >200 MB from a tiny upload.
            forged[i + 24] = 0;
            forged[i + 25] = 0;
            forged[i + 26] = 0;
            forged[i + 27] = 0x10;
            break;
          }
        }
        expect(() => importer.parseArchive(forged), throwsA(isA<ApiError>()));
      } finally {
        await store.close();
        temporary.deleteSync(recursive: true);
      }
    },
  );
  test('backup restores document snapshot consistently', () async {
    final temporary = Directory.systemTemp.createTempSync('semob-backup-test-');
    final store = await LocalDocumentStore.open(
      '${temporary.path}/docs.sembast',
    );
    try {
      final importer = DatasetImporter(store);
      const header = 'date,turnstile,advance_sales,non_paying,total\n';
      await importer.import(
        importer.parseCsv(
          '${header}2026-08-01,1,2,3,6\n',
          'passenger_days',
          'first.csv',
        ),
      );
      await backupData(store, '${temporary.path}/backup.json.gz');
      await importer.import(
        importer.parseCsv(
          '${header}2026-08-01,2,2,3,7\n',
          'passenger_days',
          'next.csv',
        ),
      );
      await restoreData(store, '${temporary.path}/backup.json.gz');
      expect(
        (await store.read(
          await store.generation(),
          'passenger_days',
        )).single['total'],
        6,
      );
    } finally {
      await store.close();
      temporary.deleteSync(recursive: true);
    }
  });
  test(
    '44 HTMLs produce lossless raw CSVs, canonical records and explicit coverage',
    () async {
      final temporary = Directory.systemTemp.createTempSync(
        'semob-documents-test-',
      );
      final store = await LocalDocumentStore.open(
        '${temporary.path}/transport.sembast',
      );
      try {
        final importer = DatasetImporter(store);
        final parsed = importer.parseArchive(privateArchive.readAsBytesSync());
        final summary = await importer.import(
          parsed,
          exportDirectory: '${temporary.path}/csv',
        );
        expect(summary['counts']['source_files'], 44);
        expect(summary['counts']['trips'], 91108);
        final service = DataService(store);
        final august = await service.resource('operation', {
          'period': '2026-08',
        });
        expect(
          august.fold<num>(0, (s, r) => s + (r['scheduledTrips'] as num)),
          35050,
        );
        expect(
          august.fold<num>(0, (s, r) => s + (r['completedTrips'] as num)),
          34994,
        );
        final coverage = await service.coverage({'period': '2026-07'});
        expect(coverage['domains']['passengers']['days'], 17);
        expect(coverage['domains']['passengers']['complete'], false);
        final july = await service.table('passenger_days', '2026-07');
        expect(
          (july.map((r) => r['date']).toList()..sort()).first,
          '2026-07-15',
        );
        final latePage = await service.page({
          'period': '2026-08',
          'offset': '30000',
          'limit': '50',
        });
        expect(latePage['items'], hasLength(50));
        final filtered = await service.page({
          'period': '2026-08',
          'line': '03',
          'status': 'notCompleted',
          'limit': '500',
        });
        expect(
          (filtered['items'] as List).every(
            (r) => r['line'] == '03' && r['status'] == 'notCompleted',
          ),
          true,
        );
        final flows = await service.table('financial_flows', '2026-09');
        expect(
          flows.firstWhere((r) => r['date'] == '2026-09-01')['total_usage'],
          14800,
        );
        final csv = csvDecode(
          await File('${temporary.path}/csv/trips.csv').readAsString(),
        );
        expect(csv.length, 91109);
        expect(
          Directory('${temporary.path}/csv/raw').listSync().length,
          parsed.rawFiles.length,
        );
        expect(
          jsonDecode(
            await File('${temporary.path}/csv/manifest.json').readAsString(),
          )['counts']['trips'],
          91108,
        );
      } finally {
        await store.close();
        temporary.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: privateArchive.existsSync()
        ? false
        : 'Relatórios privados fora do Git. Configure SEMOB_TEST_DATA_ARCHIVE para a validação completa.',
  );

  test(
    'CSV import merges history, rejects invalid data, persists and publishes atomically',
    () async {
      final temporary = Directory.systemTemp.createTempSync('semob-csv-test-');
      var store = await LocalDocumentStore.open(
        '${temporary.path}/transport.sembast',
      );
      try {
        var importer = DatasetImporter(store);
        const header = 'date,turnstile,advance_sales,non_paying,total\n';
        final first = importer.parseCsv(
          '${header}2026-07-15,10,20,30,60\n',
          'passenger_days',
          'first.csv',
        );
        await importer.import(first);
        final gen = await store.generation();
        expect(
          () => importer.parseCsv(
            '${header}2026-02-30,0,0,0,0\n',
            'passenger_days',
            'bad.csv',
          ),
          throwsA(isA<Exception>()),
        );
        expect(await store.generation(), gen);
        await importer.import(
          importer.parseCsv(
            '${header}2026-08-01,5,5,5,15\n',
            'passenger_days',
            'next.csv',
          ),
        );
        expect(
          await store.read(await store.generation(), 'passenger_days'),
          hasLength(2),
        );
        await expectLater(
          store.publish('stale', 'bad', [], {}),
          throwsStateError,
        );
        expect(await store.generation(), isNot('bad'));
        await store.close();
        store = await LocalDocumentStore.open(
          '${temporary.path}/transport.sembast',
        );
        importer = DatasetImporter(store);
        await importer.import(
          importer.parseCsv(
            '${header}2026-08-01,6,6,6,18\n',
            'passenger_days',
            'correction.csv',
          ),
        );
        final august = await store.read(
          await store.generation(),
          'passenger_days',
          period: '2026-08',
        );
        expect(august.single['total'], 18);
        expect(await store.read(gen, 'passenger_days'), hasLength(1));
      } finally {
        await store.close();
        temporary.deleteSync(recursive: true);
      }
    },
  );
  test(
    'CSV codec handles commas, quotes, newlines and protects spreadsheet exports',
    () {
      final rows = [
        {'name': 'a,"b"\nc', 'formula': '=1+1', 'value': 12.5},
      ];
      final csv = csvEncode(rows, columns: ['name', 'formula', 'value']);
      final decoded = csvDecode(csv);
      expect(decoded[1][0], rows[0]['name']);
      expect(decoded[1][1], "'=1+1");
      expect(decoded[1][2], '12.5');
    },
  );
}
