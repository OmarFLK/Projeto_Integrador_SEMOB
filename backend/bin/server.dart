import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:semob_backend/api.dart';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/data_service.dart';
import 'package:semob_backend/dataset_importer.dart';
import 'package:semob_backend/document_store.dart';

Future<void> main() async {
  final env = Platform.environment;
  String? setting(String key) {
    final value = env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  final production = env['SEMOB_ENV'] == 'production';
  if (production && env['SEMOB_EXPOSE_RECOVERY_CODE'] == 'true') {
    throw StateError('Código de recuperação não pode ser exposto em produção.');
  }
  if (production && (env['SEMOB_ALLOWED_ORIGINS'] ?? '').isEmpty) {
    throw StateError('Configure SEMOB_ALLOWED_ORIGINS em produção.');
  }
  for (final key in ['SEMOB_AI_URL', 'SEMOB_RECOVERY_WEBHOOK']) {
    final value = setting(key);
    if (value != null &&
        (!Uri.parse(value).hasAuthority ||
            production && Uri.parse(value).scheme != 'https')) {
      throw StateError('$key deve ser uma URL HTTPS em produção.');
    }
  }
  final databaseUrl = setting('DATABASE_URL');
  if (databaseUrl == null) {
    throw StateError(
      'Configure DATABASE_URL com a conexão PostgreSQL/Neon. SQLite não é usado pela API.',
    );
  }
  // Production uses a real external document database, not an ephemeral file.
  if (production && setting('SEMOB_MONGODB_URI') == null) {
    throw StateError('Configure SEMOB_MONGODB_URI em produção.');
  }
  final directUrl = setting('DIRECT_DATABASE_URL');
  if (directUrl != null) {
    final migration = await AuthStore.open(directUrl);
    await migration.close();
  }
  final auth = await AuthStore.open(databaseUrl, migrate: directUrl == null);
  if (await auth.isEmpty) {
    final password = env['SEMOB_ADMIN_PASSWORD'];
    if (password == null) {
      throw StateError(
        'No primeiro início, configure SEMOB_ADMIN_PASSWORD (mínimo 12 caracteres).',
      );
    }
    await auth.bootstrap({
      'email': env['SEMOB_ADMIN_EMAIL'] ?? 'admin@semob.local',
      'name': 'Administrador SEMOB',
      'password': password,
      'accessLevel': 'administrator',
    });
  }
  final mongo = setting('SEMOB_MONGODB_URI');
  final DocumentStore store = mongo == null
      ? await LocalDocumentStore.open(
          env['SEMOB_DOCUMENT_DATABASE'] ?? 'data/transport.sembast',
        )
      : await MongoDocumentStore.open(mongo);
  if ((await store.generation()).isEmpty) {
    final archive = File(
      env['SEMOB_DATA_ARCHIVE'] ?? 'data/semob_transport_reports.zip',
    );
    if (await archive.exists()) {
      stdout.writeln('Importando relatórios para o banco de documentos...');
      final importer = DatasetImporter(store);
      await importer.import(importer.parseArchive(await archive.readAsBytes()));
    }
  }
  final api = SemobApi(
    DataService(store),
    auth,
    production: production,
    allowedOrigins: (env['SEMOB_ALLOWED_ORIGINS'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    aiUrl: setting('SEMOB_AI_URL'),
    aiKey: setting('SEMOB_AI_API_KEY'),
    aiRequestField: env['SEMOB_AI_REQUEST_FIELD'] ?? 'message',
    aiResponseField: env['SEMOB_AI_RESPONSE_FIELD'] ?? 'answer',
    recoveryWebhook: setting('SEMOB_RECOVERY_WEBHOOK'),
    recoveryWebhookKey: setting('SEMOB_RECOVERY_WEBHOOK_KEY'),
    exposeRecoveryCode:
        !production && env['SEMOB_EXPOSE_RECOVERY_CODE'] == 'true',
  );
  final server = await shelf_io.serve(
    api.handler,
    env['SEMOB_HOST'] ?? '127.0.0.1',
    int.parse(env['PORT'] ?? env['SEMOB_PORT'] ?? '8081'),
  );
  stdout.writeln(
    'SEMOB API: http://${server.address.host}:${server.port}; usuários: PostgreSQL; transporte: ${store.engine}',
  );
  Future<void> shutdown() async {
    await server.close(force: true);
    await auth.close();
    await store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => shutdown());
  }
}
