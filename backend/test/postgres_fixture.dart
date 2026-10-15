import 'dart:io';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/postgres_database.dart';

class PostgresFixture {
  PostgresFixture._(this.admin, this.name, this.url);
  final PostgresDatabase admin;
  final String name, url;
  final List<AuthStore> stores = [];

  static Future<PostgresFixture> create() async {
    final base = Platform.environment['SEMOB_TEST_DATABASE_URL'];
    if (base == null) {
      throw StateError(
        'Configure SEMOB_TEST_DATABASE_URL com um PostgreSQL de testes (permissão CREATEDB). Nunca use credenciais de produção.',
      );
    }
    final admin = PostgresDatabase(base);
    final name =
        'semob_test_${DateTime.now().microsecondsSinceEpoch}_${secureToken().replaceAll(RegExp('[^a-zA-Z0-9]'), '').substring(0, 8).toLowerCase()}';
    await admin.execute('CREATE DATABASE $name');
    return PostgresFixture._(
      admin,
      name,
      Uri.parse(base).replace(path: '/$name').toString(),
    );
  }

  Future<AuthStore> open() async {
    final auth = await AuthStore.open(url);
    stores.add(auth);
    return auth;
  }

  Future<void> close() async {
    for (final auth in stores) {
      await auth.close();
    }
    if (!RegExp(r'^semob_test_[a-z0-9_]+$').hasMatch(name)) {
      throw StateError('Banco de teste inválido.');
    }
    await admin.execute('DROP DATABASE $name');
    await admin.close();
  }
}
