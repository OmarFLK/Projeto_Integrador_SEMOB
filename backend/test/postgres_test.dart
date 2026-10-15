import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/errors.dart';
import 'package:semob_backend/identity_transfer.dart';
import 'package:semob_backend/postgres_database.dart';
import 'package:postgres/postgres.dart' show ServerException;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'postgres_fixture.dart';

void main() {
  test(
    'remote PostgreSQL verifies TLS and unsupported channel binding fails explicitly',
    () {
      final uri = Uri.parse(
        normalizeDatabaseUrl(
          'postgresql://u:p@ep-test.neon.tech/users?sslmode=require',
        ),
      );
      expect(uri.queryParameters['sslmode'], 'verify-full');
      expect(uri.queryParameters['max_connection_count'], '5');
      expect(
        () => normalizeDatabaseUrl(
          'postgresql://u:p@ep-test.neon.tech/users?sslmode=disable',
        ),
        throwsArgumentError,
      );
      expect(
        () => normalizeDatabaseUrl(
          'postgresql://u:p@ep-test.neon.tech/users?channel_binding=require',
        ),
        throwsArgumentError,
      );
    },
  );

  late PostgresFixture fixture;
  late AuthStore auth;
  late Directory temp;
  setUp(() async {
    fixture = await PostgresFixture.create();
    auth = await fixture.open();
    temp = Directory.systemTemp.createTempSync('semob-pg-transfer-');
  });
  tearDown(() async {
    await fixture.close();
    temp.deleteSync(recursive: true);
  });

  test(
    'SQLite migration preserves credentials, sessions, recovery, preferences and audit; repeat is safe',
    () async {
      final hash = await auth.hashPassword('legacy-password-12345');
      final source = sqlite3.open('${temp.path}/users.sqlite');
      source.execute('''
      CREATE TABLE users(id TEXT PRIMARY KEY,email TEXT UNIQUE COLLATE NOCASE,identifier TEXT UNIQUE,name TEXT,job_title TEXT,department TEXT,role TEXT,active INTEGER,password_hash TEXT,created_at TEXT,last_access TEXT);
      CREATE TABLE sessions(token_hash TEXT PRIMARY KEY,user_id TEXT,expires_at TEXT);
      CREATE TABLE recovery(id TEXT PRIMARY KEY,user_id TEXT,code_hash TEXT,expires_at TEXT,attempts INTEGER,reset_hash TEXT,verified INTEGER,consumed INTEGER);
      CREATE TABLE preferences(user_id TEXT PRIMARY KEY,json TEXT);
      CREATE TABLE audit(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id TEXT,action TEXT,created_at TEXT,details TEXT);
    ''');
      final expiry = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();
      source.execute('INSERT INTO users VALUES(?,?,?,?,?,?,?,?,?,?,?)', [
        'legacy-id',
        'legacy@example.org',
        'M001',
        'José',
        'Fiscal',
        'SEMOB',
        'administrator',
        1,
        hash,
        '2026-01-01T00:00:00Z',
        null,
      ]);
      source.execute('INSERT INTO sessions VALUES(?,?,?)', [
        tokenHash('old-session'),
        'legacy-id',
        expiry,
      ]);
      source.execute('INSERT INTO recovery VALUES(?,?,?,?,?,?,?,?)', [
        'challenge',
        'legacy-id',
        tokenHash('challenge:123456'),
        expiry,
        0,
        null,
        0,
        0,
      ]);
      source.execute('INSERT INTO preferences VALUES(?,?)', [
        'legacy-id',
        '{"compact":true}',
      ]);
      source.execute('INSERT INTO audit VALUES(?,?,?,?,?)', [
        75,
        'legacy-id',
        'legacy.event',
        '2026-01-01T00:00:00Z',
        '{}',
      ]);
      source.close();
      final before = File('${temp.path}/users.sqlite').readAsBytesSync();
      final snapshot = readSqliteIdentity('${temp.path}/users.sqlite');
      final result = await importIdentity(auth, snapshot);
      expect(result['counts'], {
        'users': 1,
        'sessions': 1,
        'recovery': 1,
        'preferences': 1,
        'audit': 1,
      });
      expect((await auth.authenticate('old-session'))?['name'], 'José');
      expect((await auth.preferences('legacy-id'))['compact'], true);
      expect(
        (await auth.login('M001', 'legacy-password-12345'))['user']['id'],
        'legacy-id',
      );
      expect(
        (await auth.db.select(
          'SELECT password_hash FROM users',
        )).single['password_hash'],
        hash,
      );
      expect((await importIdentity(auth, snapshot))['alreadyImported'], true);
      expect(
        (await auth.db.select('SELECT MAX(id) AS id FROM audit')).single['id'],
        76,
      );
      final reset = await auth.verifyRecovery('challenge', '123456');
      await auth.resetPassword('challenge', reset, 'new-password-12345');
      expect(await auth.authenticate('old-session'), isNull);
      expect(File('${temp.path}/users.sqlite').readAsBytesSync(), before);
      await auth.migrate();
      expect(await auth.listUsers(), hasLength(1));
    },
  );

  test(
    'failed transfer rolls back all rows and never replaces existing users',
    () async {
      final original = await auth.createUser({
        'name': 'Original',
        'email': 'original@example.org',
        'password': 'original-pass-123',
        'accessLevel': 'administrator',
      });
      final snapshot = await exportIdentity(auth);
      // Change content so it is a different source, and reject a populated target.
      await expectLater(importIdentity(auth, snapshot), throwsStateError);
      expect((await auth.listUsers()).single['id'], original['id']);
      final target = await PostgresFixture.create();
      try {
        final empty = await target.open();
        final tables = snapshot['tables'] as Map;
        final users = tables['users'] as List;
        users.add(<String, dynamic>{
          ...Map<String, dynamic>.from(users.single as Map),
          'id': 'other',
          'email': 'ORIGINAL@EXAMPLE.ORG',
        });
        await expectLater(
          importIdentity(empty, snapshot),
          throwsA(
            isA<ServerException>().having(
              (error) => error.code,
              'SQLSTATE',
              '23505',
            ),
          ),
        );
        expect(await empty.isEmpty, true);
        expect(await empty.audit(), isEmpty);
        expect(
          await empty.db.select('SELECT * FROM identity_imports'),
          isEmpty,
        );
      } finally {
        await target.close();
      }
    },
  );

  test(
    'logical PostgreSQL backup restores identity and detects corruption',
    () async {
      final original = await auth.createUser({
        'name': 'Backup',
        'email': 'backup@example.org',
        'password': 'backup-password-123',
        'accessLevel': 'administrator',
      });
      await auth.savePreferences(original['id'] as String, {'compact': true});
      final session =
          (await auth.login(
                'backup@example.org',
                'backup-password-123',
              ))['token']
              as String;
      final file = '${temp.path}/identity.json.gz';
      await backupIdentity(auth, file);
      final target = await PostgresFixture.create();
      try {
        final restored = await target.open();
        await restoreIdentity(restored, file);
        expect((await restored.authenticate(session))?['id'], original['id']);
        expect(
          (await restored.preferences(original['id'] as String))['compact'],
          true,
        );
        expect(
          (await restored.login(
            'backup@example.org',
            'backup-password-123',
          ))['user']['id'],
          original['id'],
        );
        final envelope =
            jsonDecode(utf8.decode(gzip.decode(File(file).readAsBytesSync())))
                as Map;
        envelope['sha256'] = 'broken';
        File(
          file,
        ).writeAsBytesSync(gzip.encode(utf8.encode(jsonEncode(envelope))));
        await expectLater(
          restoreIdentity(restored, file),
          throwsFormatException,
        );
      } finally {
        await target.close();
      }
    },
  );

  test(
    'two connections cannot concurrently demote both administrators or bootstrap duplicate accounts',
    () async {
      final second = await fixture.open();
      final input = {
        'name': 'First',
        'email': 'first@example.org',
        'password': 'admin-password-123',
        'accessLevel': 'administrator',
      };
      await Future.wait([auth.bootstrap(input), second.bootstrap(input)]);
      final first = (await auth.listUsers()).single;
      final other = await auth.createUser({
        ...input,
        'email': 'second@example.org',
      });
      Future<bool> demote(AuthStore store, String id) async {
        try {
          await store.updateUser(id, {
            'accessLevel': 'operator',
          }, 'external-admin');
          return true;
        } on ApiError catch (error) {
          expect(error.status, 409);
          return false;
        }
      }

      final results = await Future.wait([
        demote(auth, first['id'] as String),
        demote(second, other['id'] as String),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(
        (await auth.listUsers()).where(
          (u) => u['accessLevel'] == 'administrator' && u['active'] == true,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'five failed recovery attempts persist and invalidate the challenge',
    () async {
      await auth.createUser({
        'name': 'Recovery',
        'email': 'recovery@example.org',
        'password': 'recovery-password-123',
        'accessLevel': 'administrator',
      });
      final challenge = await auth.startRecovery('recovery@example.org');
      for (var i = 0; i < 5; i++) {
        await expectLater(
          auth.verifyRecovery(challenge['challengeId'] as String, 'wrong'),
          throwsA(isA<ApiError>()),
        );
      }
      await expectLater(
        auth.verifyRecovery(
          challenge['challengeId'] as String,
          challenge['code'] as String,
        ),
        throwsA(isA<ApiError>()),
      );
      expect(
        (await auth.db.select(
          'SELECT attempts FROM recovery',
        )).single['attempts'],
        5,
      );
    },
  );
}
