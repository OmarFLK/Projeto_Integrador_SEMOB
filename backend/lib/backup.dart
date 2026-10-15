import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'document_store.dart';
import 'dataset_importer.dart';

Future<void> backupData(DocumentStore store, String path) async {
  final manifest = await store.manifest();
  final generation = manifest['generation'] as String;
  final rows = <Document>[];
  for (final table in dataTables) {
    rows.addAll(await store.read(generation, table));
  }
  final payload = jsonEncode({
    'version': 1,
    'manifest': manifest,
    'rows': rows,
  });
  final envelope = jsonEncode({
    'checksum': sha256.convert(utf8.encode(payload)).toString(),
    'payload': payload,
  });
  final file = File(path);
  await file.parent.create(recursive: true);
  if (await file.exists()) {
    throw StateError('O destino do backup já existe. Escolha outro nome.');
  }
  await file.writeAsBytes(gzip.encode(utf8.encode(envelope)), flush: true);
}

Future<void> restoreData(DocumentStore store, String path) async {
  final value =
      jsonDecode(utf8.decode(gzip.decode(await File(path).readAsBytes())))
          as Map<String, dynamic>;
  final payload = value['payload'] as String;
  if (sha256.convert(utf8.encode(payload)).toString() != value['checksum']) {
    throw const FormatException('Checksum do backup inválido.');
  }
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  if (decoded['version'] != 1) {
    throw const FormatException('Versão de backup não suportada.');
  }
  final rows = (decoded['rows'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  for (final row in rows) {
    if (!dataTables.contains(row['table']) || row['key'] is! String) {
      throw const FormatException('Documento inválido no backup.');
    }
    if (schemas.containsKey(row['table'])) {
      validateRecord(row['table'] as String, row);
    }
  }
  final expected = await store.generation();
  final generation = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  await store.publish(
    expected,
    generation,
    rows,
    Map<String, dynamic>.from(decoded['manifest'] as Map)
      ..remove('generation')
      ..['restoredAt'] = DateTime.now().toUtc().toIso8601String(),
  );
}
