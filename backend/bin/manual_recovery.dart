import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/errors.dart';
import 'package:semob_backend/manual_recovery.dart';

Future<void> main(List<String> args) async {
  const usage =
      '''Recuperação administrativa SEMOB (conexão de administrador do banco).
  dart run bin/manual_recovery.dart list [--status=pending]
  dart run bin/manual_recovery.dart inspect --id=ID
  dart run bin/manual_recovery.dart approve --id=ID --identity-verified [--dry-run]
  dart run bin/manual_recovery.dart reject --id=ID [--dry-run]
  dart run bin/manual_recovery.dart sql --id=ID --identity-verified
  dart run bin/manual_recovery.dart cleanup

Configure DIRECT_DATABASE_URL ou DATABASE_URL no processo. Nunca passe senhas
como argumentos. Confirme a identidade por um canal conhecido antes de aprovar.
O comando sql apenas imprime uma transação revisável; execute-a no Neon após revisão.
''';
  if (args.isEmpty || args.contains('--help')) {
    stdout.write(usage);
    return;
  }
  final command = args.first;
  if (![
        'list',
        'inspect',
        'approve',
        'reject',
        'sql',
        'cleanup',
      ].contains(command) ||
      args
          .skip(1)
          .any(
            (a) =>
                !a.startsWith('--id=') &&
                !a.startsWith('--status=') &&
                !['--identity-verified', '--dry-run'].contains(a),
          )) {
    stderr.write(usage);
    exitCode = 64;
    return;
  }
  String? option(String key) => args
      .where((a) => a.startsWith('--$key='))
      .firstOrNull
      ?.substring(key.length + 3);
  final id = option('id');
  if (['inspect', 'approve', 'reject', 'sql'].contains(command) &&
      (id == null || !RegExp(r'^[A-Za-z0-9_=-]{20,128}$').hasMatch(id))) {
    stderr.writeln('Informe --id com um ID válido.');
    exitCode = 64;
    return;
  }
  if (['approve', 'sql'].contains(command) &&
      !args.contains('--identity-verified')) {
    stderr.writeln('Verifique a identidade e informe --identity-verified.');
    exitCode = 64;
    return;
  }
  if (command == 'sql') {
    stdout.write(manualRecoveryApprovalSql(id!));
    return;
  }
  final url =
      Platform.environment['DIRECT_DATABASE_URL'] ??
      Platform.environment['DATABASE_URL'];
  if (url == null || url.trim().isEmpty) {
    stderr.writeln('Configure DIRECT_DATABASE_URL ou DATABASE_URL.');
    exitCode = 64;
    return;
  }
  AuthStore? auth;
  try {
    // Migrations are a separate, explicit operation; dry-run never changes schema.
    auth = await AuthStore.open(url, migrate: false);
    final store = ManualRecoveryStore(auth);
    if (args.contains('--dry-run')) {
      final rows = await auth.db.select(
        'SELECT id,status,expires_at,user_id IS NOT NULL AS account_linked FROM manual_recovery_requests WHERE id=?',
        [id],
      );
      stdout.writeln(
        jsonEncode({'dryRun': true, 'action': command, 'request': rows}),
      );
      return;
    }
    switch (command) {
      case 'list':
        stdout.writeln(
          const JsonEncoder.withIndent(
            '  ',
          ).convert(await store.list(status: option('status'))),
        );
      case 'inspect':
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert(await store.inspect(id!)),
        );
      case 'approve':
        await store.approve(id!, actor: 'manual:cli', identityVerified: true);
        stdout.writeln('Senha redefinida; sessões revogadas.');
      case 'reject':
        await store.reject(id!, actor: 'manual:cli');
        stdout.writeln('Solicitação rejeitada.');
      case 'cleanup':
        await auth.db.transaction(() => store.expire());
        stdout.writeln('Solicitações expiradas saneadas.');
    }
  } on ApiError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'Falha ao executar. Confira conexão, permissões e migrações do banco.',
    );
    exitCode = 1;
  } finally {
    await auth?.close();
  }
}
