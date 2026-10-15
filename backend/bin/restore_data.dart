import 'dart:io';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/backup.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError(
      'Uso: dart run bin/restore_data.dart caminho/transport.json.gz',
    );
  }
  final env = Platform.environment;
  final DocumentStore store = env['SEMOB_MONGODB_URI'] == null
      ? await LocalDocumentStore.open(
          env['SEMOB_DOCUMENT_DATABASE'] ?? 'data/transport.sembast',
        )
      : await MongoDocumentStore.open(env['SEMOB_MONGODB_URI']!);
  try {
    await restoreData(store, args[0]);
    stdout.writeln(
      'Dados restaurados em uma nova versão. Banco de usuários preservado.',
    );
  } finally {
    await store.close();
  }
}
