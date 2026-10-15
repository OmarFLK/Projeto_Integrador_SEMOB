import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'auth_store.dart';
import 'document_store.dart';
import 'identity_migrations.dart';

Future<Document> exportIdentity(
  AuthStore auth,
) => auth.db.transaction(() async {
  final tables = <String, dynamic>{};
  for (final entry in identityColumns.entries) {
    tables[entry.key] = await auth.db.select(
      'SELECT ${entry.value.join(',')} FROM ${entry.key} ORDER BY ${entry.value.first}',
    );
  }
  return {'format': 'semob-identity-v1', 'tables': tables};
}, snapshot: true);

Future<Document> importIdentity(AuthStore auth, Document snapshot) async {
  if (snapshot['format'] != 'semob-identity-v1' || snapshot['tables'] is! Map) {
    throw FormatException('Formato de identidade inválido.');
  }
  final tables = Map<String, dynamic>.from(snapshot['tables'] as Map);
  final canonical = <String, dynamic>{};
  for (final entry in identityColumns.entries) {
    final rows = tables[entry.key];
    if (rows is! List) throw FormatException('Tabela ausente: ${entry.key}.');
    canonical[entry.key] =
        rows.map((row) {
          if (row is! Map || !entry.value.every(row.containsKey)) {
            throw FormatException('Colunas inválidas: ${entry.key}.');
          }
          return {
            for (final column in entry.value)
              column: _normalize(column, row[column]),
          };
        }).toList()..sort(
          (a, b) =>
              '${a[entry.value.first]}'.compareTo('${b[entry.value.first]}'),
        );
  }
  final hash = tokenHash(jsonEncode(canonical));
  return auth.db.transaction(() async {
    final previous = await auth.db.select(
      'SELECT counts FROM identity_imports WHERE source_hash=?',
      [hash],
    );
    if (previous.isNotEmpty) {
      return {
        'alreadyImported': true,
        'counts': jsonDecode(previous.single['counts'] as String),
      };
    }
    for (final table in identityColumns.keys) {
      if ((await auth.db.select('SELECT 1 FROM $table LIMIT 1')).isNotEmpty) {
        throw StateError(
          'O destino precisa estar vazio. Migre antes do primeiro início da API; nenhuma conta será sobrescrita.',
        );
      }
    }
    final counts = <String, int>{};
    for (final entry in identityColumns.entries) {
      final rows = canonical[entry.key] as List;
      for (final row in rows) {
        if (entry.key == 'users' &&
            !(row['password_hash'] as String).startsWith('pbkdf2-sha256:')) {
          throw FormatException(
            'O SQLite legado não contém hashes compatíveis; contas demonstrativas não podem ser migradas.',
          );
        }
        await auth.db.execute(
          'INSERT INTO ${entry.key}(${entry.value.join(',')}) VALUES(${List.filled(entry.value.length, '?').join(',')})',
          [for (final column in entry.value) row[column]],
        );
      }
      final actual = await auth.db.select(
        'SELECT ${entry.value.join(',')} FROM ${entry.key}',
      );
      final normalized =
          actual
              .map(
                (row) => {
                  for (final column in entry.value)
                    column: _normalize(column, row[column]),
                },
              )
              .toList()
            ..sort(
              (a, b) => '${a[entry.value.first]}'.compareTo(
                '${b[entry.value.first]}',
              ),
            );
      if (jsonEncode(normalized) != jsonEncode(rows)) {
        throw StateError('Verificação de integridade falhou: ${entry.key}.');
      }
      counts[entry.key] = rows.length;
    }
    await auth.db.execute(
      "SELECT setval(pg_get_serial_sequence('audit','id'), GREATEST(COALESCE((SELECT MAX(id) FROM audit),0)+1,1), false)",
    );
    await auth.db.execute(
      'INSERT INTO identity_imports(source_hash,counts) VALUES(?,?)',
      [hash, jsonEncode(counts)],
    );
    return {'alreadyImported': false, 'counts': counts};
  });
}

Object? _normalize(String column, Object? value) {
  if (value != null &&
      ['created_at', 'last_access', 'expires_at'].contains(column)) {
    return DateTime.parse(value.toString()).toUtc().toIso8601String();
  }
  return value;
}

/// Opens a real file read-only; never creates or modifies the SQLite source.
Document readSqliteIdentity(String path) {
  if (!File(path).existsSync()) {
    throw ArgumentError('Arquivo SQLite não encontrado.');
  }
  final source = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    source.execute('BEGIN');
    final tables = <String, dynamic>{};
    for (final entry in identityColumns.entries) {
      final columns = source
          .select('PRAGMA table_info(${entry.key})')
          .map((row) => row['name'])
          .toSet();
      if (!entry.value.every(columns.contains)) {
        throw FormatException(
          'SQLite incompatível: ${entry.key}. Use o users.sqlite da autenticação real, não o antigo semob.db demonstrativo.',
        );
      }
      tables[entry.key] = source
          .select(
            'SELECT ${entry.value.join(',')} FROM ${entry.key} ORDER BY ${entry.value.first}',
          )
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return {'format': 'semob-identity-v1', 'tables': tables};
  } finally {
    source.close();
  }
}

Future<void> backupIdentity(AuthStore auth, String path) async {
  final snapshot = await exportIdentity(auth);
  final payload = jsonEncode(snapshot);
  await File(path).writeAsBytes(
    gzip.encode(
      utf8.encode(
        jsonEncode({'sha256': tokenHash(payload), 'payload': payload}),
      ),
    ),
  );
}

Future<Document> restoreIdentity(AuthStore auth, String path) async {
  final envelope =
      jsonDecode(utf8.decode(gzip.decode(await File(path).readAsBytes())))
          as Map;
  final payload = envelope['payload'] as String;
  if (tokenHash(payload) != envelope['sha256']) {
    throw FormatException('Checksum do backup de identidade inválido.');
  }
  return importIdentity(
    auth,
    Map<String, dynamic>.from(jsonDecode(payload) as Map),
  );
}
