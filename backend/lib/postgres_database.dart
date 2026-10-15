import 'dart:async';
import 'package:postgres/postgres.dart';
import 'document_store.dart';

/// Each transaction pins every nested query to its own PostgreSQL session.
/// Zone values are isolated between concurrent HTTP requests.
class PostgresDatabase {
  PostgresDatabase(String url) : pool = Pool.withUrl(normalizeDatabaseUrl(url));
  final Pool pool;
  final Object _transactionKey = Object();
  Session get _session => Zone.current[_transactionKey] as Session? ?? pool;

  Future<List<Document>> select(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final result = await _session.execute(
      Sql.indexed(sql, substitution: '?'),
      parameters: args,
    );
    return result
        .map(
          (row) => row.toColumnMap().map(
            (key, value) => MapEntry(
              key,
              value is DateTime ? value.toUtc().toIso8601String() : value,
            ),
          ),
        )
        .toList();
  }

  Future<void> execute(String sql, [List<Object?> args = const []]) async {
    await select(sql, args);
  }

  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool snapshot = false,
  }) {
    if (Zone.current[_transactionKey] != null) return action();
    return pool.runTx(
      (session) => runZoned(() async {
        if (snapshot) {
          await execute(
            'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY',
          );
        } else {
          // Serialize identity writes, including bootstrap and last-admin checks,
          // across processes/replicas; safe with transaction-mode PgBouncer.
          await execute('SELECT pg_advisory_xact_lock(73636601)');
        }
        return action();
      }, zoneValues: {_transactionKey: session}),
    );
  }

  Future<void> close() => pool.close();
}

String normalizeDatabaseUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !['postgres', 'postgresql'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.pathSegments.isEmpty ||
      uri.userInfo.isEmpty) {
    throw ArgumentError(
      'DATABASE_URL deve ser uma URL PostgreSQL com usuário, host e banco.',
    );
  }
  final local = [
    'localhost',
    '127.0.0.1',
    '::1',
    'postgres',
  ].contains(uri.host);
  final params = {...uri.queryParameters};
  // The driver supports SCRAM-SHA-256, but not SCRAM-SHA-256-PLUS.
  // Never silently discard Neon's channel_binding=require setting.
  if (params.containsKey('channel_binding')) {
    throw ArgumentError(
      'O driver Dart não suporta channel_binding. Remova esse parâmetro da URL do Neon e use sslmode=verify-full.',
    );
  }
  if (!local) {
    if (params['sslmode'] == 'disable') {
      throw ArgumentError(
        'PostgreSQL remoto exige TLS. Use sslmode=verify-full.',
      );
    }
    params['sslmode'] = 'verify-full';
  } else {
    params.putIfAbsent('sslmode', () => 'disable');
  }
  params.putIfAbsent('connect_timeout', () => '30');
  params.putIfAbsent('query_timeout', () => '30');
  params.putIfAbsent('max_connection_count', () => '5');
  params.putIfAbsent('application_name', () => 'semob');
  return uri.replace(queryParameters: params).toString();
}
