import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_io.dart';

typedef Document = Map<String, dynamic>;

abstract class DocumentStore {
  String get engine;
  Future<String> generation();
  Future<List<Document>> read(
    String generation,
    String table, {
    String? period,
  });
  Future<void> publish(
    String expected,
    String generation,
    List<Document> rows,
    Document manifest,
  );
  Future<Document> manifest();

  /// Stores can aggregate filter values without transferring complete trips.
  Future<Document?> filterOptions(String generation, String period) async =>
      null;
  Future<void> close();
  Future<bool> ready() async {
    await manifest();
    return true;
  }
}

String recordKey(String table, Document row) {
  final fields = switch (table) {
    'source_files' => ['path'],
    'line_days' => ['date', 'line'],
    'credit_balances' => ['date', 'series'],
    'trips' => [
      'date',
      'line',
      'prefix',
      'activity',
      'direction',
      'started_at',
      'finished_at',
    ],
    'anomalies' => [
      'date',
      'line',
      'kind',
      'service',
      'schedule_code',
      'scheduled_start',
      'direction',
    ],
    'time_range_line_stats' => ['date', 'line', 'time_range'],
    'time_range_summaries' => ['date', 'time_range'],
    _ => ['date'],
  };
  return sha256
      .convert(
        utf8.encode('$table:${fields.map((f) => row[f] ?? '').join('|')}'),
      )
      .toString();
}

class LocalDocumentStore extends DocumentStore {
  LocalDocumentStore._(this.db);
  final sembast.Database db;
  final records = sembast.stringMapStoreFactory.store('documents');
  final metadata = sembast.stringMapStoreFactory.store('metadata');
  static Future<LocalDocumentStore> open(String path) async {
    await File(path).parent.create(recursive: true);
    return LocalDocumentStore._(
      await databaseFactoryIo.openDatabase(path, version: 1),
    );
  }

  @override
  String get engine => 'sembast';
  @override
  Future<Document> manifest() async =>
      (await metadata.record('active').get(db)) ?? {};
  @override
  Future<String> generation() async =>
      (await manifest())['generation'] as String? ?? '';
  @override
  Future<List<Document>> read(
    String generation,
    String table, {
    String? period,
  }) async {
    if (generation.isEmpty) return [];
    final found = await records.find(
      db,
      finder: sembast.Finder(
        filter: sembast.Filter.and([
          sembast.Filter.equals('generation', generation),
          sembast.Filter.equals('table', table),
          if (period != null) sembast.Filter.equals('period', period),
        ]),
      ),
    );
    return found.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  @override
  Future<void> publish(
    String expected,
    String generation,
    List<Document> rows,
    Document manifest,
  ) async {
    await db.transaction((txn) async {
      final previous = await metadata.record('active').get(txn);
      if ((previous?['generation'] ?? '') != expected) {
        throw StateError('Outro lote foi publicado. Tente novamente.');
      }
      for (final row in rows) {
        await records.record('$generation:${row['table']}:${row['key']}').put(
          txn,
          {...row, 'generation': generation},
        );
      }
      await metadata.record('active').put(txn, {
        ...manifest,
        'generation': generation,
        'schemaVersion': 1,
      });
    });
  }

  @override
  Future<void> close() => db.close();
}

class MongoDocumentStore extends DocumentStore {
  MongoDocumentStore._(this._db, this._url);
  mongo.Db _db;
  mongo.Db get db => _db;
  final String _url;
  Future<void>? _reconnecting;
  bool _closed = false;
  static Future<MongoDocumentStore> open(String url) async {
    url = normalizeMongoUrl(url);
    final db = await mongo.Db.create(url);
    await db.open();
    await db
        .collection('documents')
        .createIndex(keys: {'generation': 1, 'table': 1, 'period': 1});
    await db
        .collection('documents')
        .createIndex(
          keys: {'generation': 1, 'table': 1, 'key': 1},
          unique: true,
        );
    try {
      await db.collection('metadata').insertOne({
        '_id': 'active',
        'generation': '',
        'schemaVersion': 1,
      });
    } catch (_) {
      if (await db.collection('metadata').findOne({'_id': 'active'}) == null) {
        rethrow;
      }
    }
    return MongoDocumentStore._(db, url);
  }

  Future<void> _reconnect(mongo.Db failed) async {
    if (_closed) throw StateError('Banco documental encerrado.');
    if (!identical(failed, _db) && _db.isConnected) return;
    final pending = _reconnecting;
    if (pending != null) return pending;
    final replacement = () async {
      final next = await mongo.Db.create(_url);
      try {
        await next.open();
        if (_closed) throw StateError('Banco documental encerrado.');
        _db = next;
      } catch (_) {
        await next.close();
        rethrow;
      }
      try {
        await failed.close();
      } catch (_) {
        // The failed socket might already have been closed by the driver.
      }
      stderr.writeln('mongodb_reconnected');
    }();
    _reconnecting = replacement;
    try {
      await replacement;
    } finally {
      _reconnecting = null;
    }
  }

  Future<T> _read<T>(Future<T> Function(mongo.Db) action) async {
    // Only repeat reads. Publication has its own ambiguity/commit handling.
    for (var attempt = 0; ; attempt++) {
      final connection = _db;
      try {
        if (_closed) throw StateError('Banco documental encerrado.');
        if (!connection.isConnected) await _reconnect(connection);
        return await action(_db);
      } catch (error) {
        if (attempt != 0 || !isMongoConnectionError(error)) rethrow;
        await _reconnect(connection);
      }
    }
  }

  @override
  String get engine => 'mongodb';
  @override
  Future<Document> manifest() async {
    final result =
        await _read(
          (connection) =>
              connection.collection('metadata').findOne({'_id': 'active'}),
        ) ??
        {};
    result.remove('_id');
    return result;
  }

  @override
  Future<String> generation() async =>
      (await manifest())['generation'] as String? ?? '';
  @override
  Future<List<Document>> read(
    String generation,
    String table, {
    String? period,
  }) async {
    if (generation.isEmpty) return [];
    final rows = await _read(
      (connection) => connection.collection('documents').find({
        'generation': generation,
        'table': table,
        'period': ?period,
      }).toList(),
    );
    for (final row in rows) {
      row.remove('_id');
    }
    return rows;
  }

  @override
  Future<Document?> filterOptions(String generation, String period) async {
    final rows = await _read(
      (connection) => connection.collection('documents').aggregateToStream([
        {
          r'$match': {
            'generation': generation,
            'table': 'trips',
            'period': period,
          },
        },
        {
          r'$group': {
            '_id': null,
            'lines': {r'$addToSet': r'$line'},
            'vehicles': {r'$addToSet': r'$prefix'},
            'directions': {r'$addToSet': r'$direction'},
            'timeRanges': {r'$addToSet': r'$time_range'},
          },
        },
      ]).toList(),
    );
    final result = rows.firstOrNull ?? {};
    return {
      for (final key in ['lines', 'vehicles', 'directions', 'timeRanges'])
        key:
            ((result[key] as List?) ?? [])
                .where((value) => value != null && value.toString().isNotEmpty)
                .map((value) => value.toString())
                .toList()
              ..sort(),
    };
  }

  @override
  Future<void> publish(
    String expected,
    String generation,
    List<Document> rows,
    Document manifest,
  ) async {
    try {
      for (var i = 0; i < rows.length; i += 500) {
        final end = (i + 500).clamp(0, rows.length);
        final result = await db
            .collection('documents')
            .insertMany(
              rows
                  .sublist(i, end)
                  .map((r) => {...r, 'generation': generation})
                  .toList(),
            );
        if (!result.isSuccess) {
          throw StateError('Falha ao gravar lote MongoDB.');
        }
      }
      final result = await db
          .collection('metadata')
          .replaceOne(
            {'_id': 'active', 'generation': expected},
            {
              '_id': 'active',
              ...manifest,
              'generation': generation,
              'schemaVersion': 1,
            },
          );
      if (!result.isSuccess || result.nMatched != 1) {
        throw StateError('Lote concorrente. Refaça a importação.');
      }
    } catch (_) {
      // A network failure can occur after the pointer was committed.
      // Never remove a generation unless we confirmed it is not active.
      try {
        if (await this.generation() == generation) return;
        await db.collection('documents').deleteMany({'generation': generation});
      } catch (_) {
        /* Leave unreferenced staging data if the server is unreachable. */
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _reconnecting;
    } finally {
      await _db.close();
    }
  }
}

String normalizeMongoUrl(String url) {
  final uri = Uri.parse(url);
  // mongo_dart multiplexing can make Atlas reset concurrent requests. Its
  // safeAtlas mode serializes commands on the socket (including getMore).
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'safeAtlas': 'true'})
      .toString();
}

bool isMongoConnectionError(Object error) {
  if (error is mongo.ConnectionException || error is SocketException) {
    return true;
  }
  if (error is! mongo.MongoDartError) return false;
  return error.message == 'No master connection' ||
      error.message.startsWith('DB is not open.') ||
      [
        6,
        7,
        89,
        91,
        189,
        9001,
        10107,
        11600,
        11602,
        13435,
        13436,
      ].contains(error.mongoCode);
}

const dataTables = [
  'operation_days',
  'fleet_compliance_days',
  'line_days',
  'time_range_line_stats',
  'time_range_summaries',
  'trips',
  'anomalies',
  'passenger_days',
  'credit_balances',
  'financial_flows',
  'source_files',
  'source_chunks',
];
