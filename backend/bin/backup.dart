import 'dart:io';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/identity_transfer.dart';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/backup.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final directory = Directory(
    args.isEmpty
        ? 'data/backups/${DateTime.now().toUtc().millisecondsSinceEpoch}'
        : args[0],
  );
  if (await directory.exists()) {
    throw StateError('Use uma pasta nova para o backup.');
  }
  await directory.create(recursive: true);
  final url = env['DIRECT_DATABASE_URL'] ?? env['DATABASE_URL'];
  if (url == null || url.isEmpty) throw StateError('Configure DATABASE_URL.');
  final users = await AuthStore.open(url, migrate: false);
  try {
    await backupIdentity(users, '${directory.path}/identity.json.gz');
  } finally {
    await users.close();
  }
  final DocumentStore store = env['SEMOB_MONGODB_URI'] == null
      ? await LocalDocumentStore.open(
          env['SEMOB_DOCUMENT_DATABASE'] ?? 'data/transport.sembast',
        )
      : await MongoDocumentStore.open(env['SEMOB_MONGODB_URI']!);
  try {
    await backupData(store, '${directory.path}/transport.json.gz');
    stdout.writeln(
      'Backup concluído em ${directory.path}. Guarde esta pasta com acesso restrito.',
    );
  } finally {
    await store.close();
  }
}
