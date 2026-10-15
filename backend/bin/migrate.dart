import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/identity_transfer.dart';

/// Run before the API's first start when importing existing SQLite accounts.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty &&
      !(args.length == 2 && ['--sqlite', '--restore'].contains(args.first))) {
    stderr.writeln(
      'Uso: dart run bin/migrate.dart [--sqlite caminho/users.sqlite | --restore caminho/identity.json.gz]',
    );
    exitCode = 64;
    return;
  }
  final env = Platform.environment;
  final url = env['DIRECT_DATABASE_URL'] ?? env['DATABASE_URL'];
  if (url == null || url.isEmpty) {
    throw StateError('Configure DIRECT_DATABASE_URL ou DATABASE_URL.');
  }
  AuthStore? auth;
  try {
    auth = await AuthStore.open(url);
    final result = args.isEmpty
        ? {'schemaVersion': 1, 'empty': await auth.isEmpty}
        : args.first == '--sqlite'
        ? await importIdentity(auth, readSqliteIdentity(args[1]))
        : await restoreIdentity(auth, args[1]);
    stdout.writeln(jsonEncode(result));
  } catch (error) {
    // Never print database URLs or driver errors containing credentials.
    stderr.writeln(
      'Migração não concluída (${error.runtimeType}). Verifique a configuração, a compatibilidade da origem e se o destino está vazio. Nenhum dado da origem foi modificado.',
    );
    exitCode = 1;
  } finally {
    await auth?.close();
  }
}
