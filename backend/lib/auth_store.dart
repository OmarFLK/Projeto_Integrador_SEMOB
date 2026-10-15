import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';
import 'package:postgres/postgres.dart';
import 'postgres_database.dart';
import 'identity_migrations.dart';
import 'document_store.dart';
import 'errors.dart';

String secureToken() => base64Url.encode(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
);
String tokenHash(String value) => sha256.convert(utf8.encode(value)).toString();
const roles = ['administrator', 'manager', 'analyst', 'operator'];
List<String> permissions(String role) => [
  'read',
  if (role != 'operator') ...['financial', 'export', 'assistant'],
  if (['administrator', 'manager'].contains(role)) 'import',
  if (role == 'administrator') 'users',
];

class AuthStore {
  AuthStore._(this.db);
  final PostgresDatabase db;
  static Future<AuthStore> open(String url, {bool migrate = true}) async {
    final store = AuthStore._(PostgresDatabase(url));
    try {
      if (migrate) await store.migrate();
      return store;
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  Future<void> migrate() => db.transaction(() async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS schema_migrations(version INTEGER PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, checksum TEXT NOT NULL)',
    );
    for (final migration in identityMigrations.entries) {
      final checksum = tokenHash(migration.value.join('\n'));
      final applied = await db.select(
        'SELECT checksum FROM schema_migrations WHERE version=?',
        [migration.key],
      );
      if (applied.isNotEmpty) {
        if (applied.single['checksum'] != checksum) {
          throw StateError(
            'Migração aplicada foi alterada: versão ${migration.key}.',
          );
        }
        continue;
      }
      for (final statement in migration.value) {
        await db.execute(statement);
      }
      await db.execute(
        'INSERT INTO schema_migrations(version,checksum) VALUES(?,?)',
        [migration.key, checksum],
      );
    }
  });

  Future<void> bootstrap(Document input) => db.transaction(() async {
    if (await isEmpty) await createUser(input);
  });

  Future<String> hashPassword(String password) async {
    if (password.length < 12 || password.length > 256) {
      throw const ApiError(400, 'A senha deve ter entre 12 e 256 caracteres.');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return 'pbkdf2-sha256:600000:${base64.encode(salt)}:${base64.encode(await hash.extractBytes())}';
  }

  Future<bool> verifyPassword(String password, String encoded) async {
    final parts = encoded.split(':');
    if (parts.length != 4) return false;
    final result = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: int.parse(parts[1]),
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: base64.decode(parts[2]));
    final actual = await result.extractBytes();
    final expected = base64.decode(parts[3]);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < min(actual.length, expected.length); i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<bool> get isEmpty async =>
      ((await db.select('SELECT COUNT(*) AS n FROM users')).first['n']
          as int) ==
      0;
  Document publicUser(Document user) => {
    'id': user['id'],
    'email': user['email'],
    'identifier': user['identifier'] ?? user['email'],
    'name': user['name'],
    'jobTitle': user['job_title'],
    'department': user['department'],
    'accessLevel': user['role'],
    'active': user['active'] == 1,
    'lastAccess': user['last_access'],
    'permissions': permissions(user['role'] as String),
  };
  Future<Document?> _user(String id) async {
    final rows = await db.select('SELECT * FROM users WHERE id=?', [id]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<Document> getUser(String id) async {
    final user = await _user(id);
    if (user == null) throw const ApiError(404, 'Usuário não encontrado.');
    return publicUser(user);
  }

  Future<List<Document>> listUsers() async => (await db.select(
    'SELECT * FROM users ORDER BY name',
  )).map(publicUser).toList();
  Future<Document> createUser(Document input, {String? actor}) async {
    _validateUserFields(input);
    final email = _text(input, 'email').trim().toLowerCase();
    final name = _text(input, 'name').trim();
    final role = input['accessLevel'] ?? 'operator';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        name.isEmpty ||
        !roles.contains(role)) {
      throw const ApiError(
        400,
        'Nome, e-mail e perfil válidos são obrigatórios.',
      );
    }
    final hash = await hashPassword(_text(input, 'password'));
    final id = secureToken();
    try {
      return await db.transaction(() async {
        await db.execute(
          'INSERT INTO users(id,email,identifier,name,job_title,department,role,password_hash,created_at) VALUES(?,?,?,?,?,?,?,?,?)',
          [
            id,
            email,
            input['identifier']?.toString().trim().isNotEmpty == true
                ? input['identifier']
                : null,
            name,
            input['jobTitle'] ?? '',
            input['department'] ?? '',
            role,
            hash,
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
        await log(actor, 'user.create', {'target': id});
        return getUser(id);
      });
    } on ServerException catch (error) {
      if (error.code != '23505') rethrow;
      throw const ApiError(409, 'E-mail ou matrícula já cadastrados.');
    }
  }

  Future<void> updateUser(
    String id,
    Document input,
    String actor,
  ) => db.transaction(() async {
    _validateUserFields(input);
    final old = await _user(id);
    if (old == null) throw const ApiError(404, 'Usuário não encontrado.');
    final role = input['accessLevel'] ?? old['role'];
    final active = input['active'] ?? (old['active'] == 1);
    if (!roles.contains(role) || active is! bool) {
      throw const ApiError(400, 'Perfil/status inválido.');
    }
    if (old['role'] == 'administrator' &&
        old['active'] == 1 &&
        (role != 'administrator' || !active) &&
        (await db.select(
              "SELECT id FROM users WHERE role='administrator' AND active=1",
            )).length <=
            1) {
      throw const ApiError(409, 'Mantenha pelo menos um administrador ativo.');
    }
    if (id == actor && !active) {
      throw const ApiError(409, 'Você não pode desativar a própria conta.');
    }
    final name = input['name'] ?? old['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const ApiError(400, 'Nome obrigatório.');
    }
    await db.execute(
      'UPDATE users SET name=?,job_title=?,department=?,role=?,active=? WHERE id=?',
      [
        name,
        input['jobTitle'] ?? old['job_title'],
        input['department'] ?? old['department'],
        role,
        active ? 1 : 0,
        id,
      ],
    );
    if (!active || role != old['role']) {
      await db.execute('DELETE FROM sessions WHERE user_id=?', [id]);
    }
    await log(actor, 'user.update', {'target': id});
  });

  Future<Document> login(
    String identifier,
    String password, {
    bool remember = false,
  }) async {
    if (identifier.isEmpty ||
        identifier.length > 250 ||
        password.isEmpty ||
        password.length > 256) {
      throw const ApiError(400, 'Informe acesso e senha.');
    }
    final rows = await db.select(
      'SELECT * FROM users WHERE email=? OR identifier=?',
      [identifier.toLowerCase(), identifier],
    );
    // Always run the password KDF, including for unknown users.
    final fallback =
        'pbkdf2-sha256:600000:${base64.encode(List.filled(16, 0))}:${base64.encode(List.filled(32, 0))}';
    final valid = await verifyPassword(
      password,
      rows.isEmpty ? fallback : rows.first['password_hash'] as String,
    );
    if (!valid || rows.isEmpty || rows.first['active'] != 1) {
      throw const ApiError(401, 'Credenciais inválidas.');
    }
    return db.transaction(() async {
      final current = await _user(rows.first['id'] as String);
      if (current == null ||
          current['active'] != 1 ||
          current['password_hash'] != rows.first['password_hash']) {
        throw const ApiError(401, 'Credenciais inválidas.');
      }
      final id = current['id'] as String;
      final token = secureToken();
      final expires = DateTime.now().toUtc().add(
        remember ? const Duration(days: 7) : const Duration(hours: 8),
      );
      await db.execute('DELETE FROM sessions WHERE expires_at<=?', [
        DateTime.now().toUtc().toIso8601String(),
      ]);
      await db.execute('INSERT INTO sessions VALUES(?,?,?)', [
        tokenHash(token),
        id,
        expires.toIso8601String(),
      ]);
      await db.execute('UPDATE users SET last_access=? WHERE id=?', [
        DateTime.now().toUtc().toIso8601String(),
        id,
      ]);
      await log(id, 'auth.login', {});
      return {
        'token': token,
        'expiresAt': expires.toIso8601String(),
        'user': await getUser(id),
      };
    });
  }

  Future<Document?> authenticate(String? token) async {
    if (token == null || token.length > 256) return null;
    final rows = await db.select(
      'SELECT users.* FROM users JOIN sessions ON sessions.user_id=users.id WHERE sessions.token_hash=? AND sessions.expires_at>? AND users.active=1',
      [tokenHash(token), DateTime.now().toUtc().toIso8601String()],
    );
    return rows.isEmpty
        ? null
        : publicUser(Map<String, dynamic>.from(rows.first));
  }

  Future<void> logout(String token) async => await db.execute(
    'DELETE FROM sessions WHERE token_hash=?',
    [tokenHash(token)],
  );
  Future<Document> preferences(String id) async {
    final rows = await db.select(
      'SELECT json FROM preferences WHERE user_id=?',
      [id],
    );
    return rows.isEmpty
        ? {'compact': false}
        : Map<String, dynamic>.from(
            jsonDecode(rows.first['json'] as String) as Map,
          );
  }

  Future<void> savePreferences(String id, Document input) async {
    if (input['compact'] is! bool) {
      throw const ApiError(400, 'Preferência inválida.');
    }
    await db.execute(
      'INSERT INTO preferences VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET json=excluded.json',
      [
        id,
        jsonEncode({'compact': input['compact']}),
      ],
    );
  }

  Future<void> log(String? id, String action, Document details) async =>
      await db.execute(
        'INSERT INTO audit(user_id,action,created_at,details) VALUES(?,?,?,?)',
        [
          id,
          action,
          DateTime.now().toUtc().toIso8601String(),
          jsonEncode(details),
        ],
      );
  Future<List<Document>> audit() => db.select(
    'SELECT user_id,action,created_at,details FROM audit ORDER BY id DESC LIMIT 100',
  );
  Future<Document> startRecovery(String email) => db.transaction(() async {
    final id = secureToken();
    final rows = await db.select(
      'SELECT id FROM users WHERE email=? AND active=1',
      [email],
    );
    if (rows.isEmpty) return {'challengeId': id};
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    await db.execute('DELETE FROM recovery WHERE user_id=? OR expires_at < ?', [
      rows.first['id'],
      DateTime.now().toUtc().toIso8601String(),
    ]);
    await db.execute(
      'INSERT INTO recovery(id,user_id,code_hash,expires_at) VALUES(?,?,?,?)',
      [
        id,
        rows.first['id'],
        tokenHash('$id:$code'),
        DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      ],
    );
    return {'challengeId': id, 'code': code};
  });

  Future<String> verifyRecovery(String id, String code) async {
    final reset = await db.transaction(() async {
      final rows = await db.select(
        'SELECT * FROM recovery WHERE id=? AND expires_at>? AND consumed=0 AND verified=0 AND attempts<5 FOR UPDATE',
        [id, DateTime.now().toUtc().toIso8601String()],
      );
      if (rows.isEmpty) return null;
      await db.execute('UPDATE recovery SET attempts=attempts+1 WHERE id=?', [
        id,
      ]);
      // Commit invalid attempts too, preventing unlimited guesses.
      if (rows.first['code_hash'] != tokenHash('$id:$code')) return null;
      final reset = secureToken();
      await db.execute(
        'UPDATE recovery SET verified=1,reset_hash=? WHERE id=?',
        [tokenHash(reset), id],
      );
      return reset;
    });
    if (reset == null) {
      throw const ApiError(400, 'Código inválido ou expirado.');
    }
    return reset;
  }

  Future<void> resetPassword(String id, String token, String password) async {
    // Reject bogus challenges before running the expensive password KDF.
    // The transaction rechecks eligibility after hashing to prevent replay.
    if (id.length > 128 ||
        token.length > 128 ||
        (await db.select(
          'SELECT id FROM recovery WHERE id=? AND reset_hash=? AND verified=1 AND consumed=0 AND expires_at>?',
          [id, tokenHash(token), DateTime.now().toUtc().toIso8601String()],
        )).isEmpty) {
      throw const ApiError(400, 'Solicitação inválida ou expirada.');
    }
    final hash = await hashPassword(password);
    await db.transaction(() async {
      final rows = await db.select(
        'SELECT user_id FROM recovery WHERE id=? AND reset_hash=? AND verified=1 AND consumed=0 AND expires_at>?',
        [id, tokenHash(token), DateTime.now().toUtc().toIso8601String()],
      );
      if (rows.isEmpty) {
        throw const ApiError(400, 'Solicitação inválida ou expirada.');
      }
      final user = rows.first['user_id'];
      await db.execute('UPDATE recovery SET consumed=1 WHERE id=?', [id]);
      await db.execute('UPDATE users SET password_hash=? WHERE id=?', [
        hash,
        user,
      ]);
      await db.execute('DELETE FROM sessions WHERE user_id=?', [user]);
      await log(user as String, 'auth.password_reset', {});
    });
  }

  Future<void> close() => db.close();
}

void _validateUserFields(Document input) {
  for (final key in ['name', 'email', 'identifier', 'jobTitle', 'department']) {
    final value = input[key];
    if (value != null && (value is! String || value.length > 250)) {
      throw ApiError(400, 'Campo $key inválido (máximo 250 caracteres).');
    }
  }
}

String _text(Document input, String key) {
  final value = input[key];
  if (value is! String) throw ApiError(400, 'Campo $key inválido.');
  return value;
}
