import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/api.dart';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/data_service.dart';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/errors.dart';
import 'package:semob_backend/identity_transfer.dart';
import 'package:semob_backend/manual_recovery.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'postgres_fixture.dart';

void main() {
  const oldPassword = 'old-test-password-12345';
  const newPassword = 'new-test-password-67890';
  late PostgresFixture fixture;
  late AuthStore auth;
  late ManualRecoveryStore manual;
  late String userId;
  setUp(() async {
    fixture = await PostgresFixture.create();
    auth = await fixture.open();
    manual = ManualRecoveryStore(auth);
    userId =
        (await auth.createUser({
              'name': 'Pessoa de teste',
              'email': 'person@example.org',
              'identifier': 'pessoa',
              'password': oldPassword,
              'accessLevel': 'operator',
            }))['id']
            as String;
  });
  tearDown(() => fixture.close());

  Future<String> request([String identifier = 'person@example.org']) =>
      manual.request(
        name: 'Nome declarado',
        identifier: identifier,
        password: newPassword,
      );

  test(
    'proposal is a compatible hash, remains pending, and is never public',
    () async {
      final id = await request();
      final stored = (await auth.db.select(
        'SELECT * FROM manual_recovery_requests WHERE id=?',
        [id],
      )).single;
      expect(stored['status'], 'pending');
      expect(
        await auth.verifyPassword(
          newPassword,
          stored['proposed_hash'] as String,
        ),
        isTrue,
      );
      expect(
        jsonEncode(await manual.list()).contains('proposed_hash'),
        isFalse,
      );
      expect(jsonEncode(await manual.list()).contains(newPassword), isFalse);
      expect((await auth.login('pessoa', oldPassword))['token'], isA<String>());
      await expectLater(
        auth.login('pessoa', newPassword),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        manual.approve(id, actor: 'test-admin', identityVerified: false),
        throwsA(isA<ApiError>()),
      );
      expect((await manual.inspect(id))['status'], 'pending');
    },
  );

  test(
    'approval revokes sessions and challenges, scrubs competitors and prevents replay',
    () async {
      final token =
          (await auth.login('pessoa', oldPassword))['token'] as String;
      final automated = await auth.startRecovery('person@example.org');
      final first = await request();
      final other = await request();
      await manual.approve(first, actor: 'test-admin', identityVerified: true);
      expect(await auth.authenticate(token), isNull);
      expect((await auth.login('pessoa', newPassword))['token'], isA<String>());
      expect((await manual.inspect(first))['status'], 'approved');
      expect((await manual.inspect(other))['status'], 'cancelled');
      expect(
        (await auth.db.select(
          'SELECT proposed_hash FROM manual_recovery_requests WHERE user_id=?',
          [userId],
        )).every((r) => r['proposed_hash'] == null),
        isTrue,
      );
      await expectLater(
        auth.verifyRecovery(
          automated['challengeId'] as String,
          automated['code'] as String,
        ),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        manual.approve(first, actor: 'test-admin', identityVerified: true),
        throwsA(isA<ApiError>()),
      );
    },
  );

  test(
    'expired, rejected, unknown and inactive accounts cannot be reset',
    () async {
      final expired = await request();
      await auth.db.execute(
        "UPDATE manual_recovery_requests SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 minute' WHERE id=?",
        [expired],
      );
      await expectLater(
        manual.approve(expired, actor: 'test-admin', identityVerified: true),
        throwsA(isA<ApiError>()),
      );
      expect((await manual.inspect(expired))['status'], 'expired');
      expect(
        (await auth.db.select(
          'SELECT proposed_hash FROM manual_recovery_requests WHERE id=?',
          [expired],
        )).single['proposed_hash'],
        isNull,
      );
      final rejected = await request();
      await manual.reject(rejected, actor: 'test-admin');
      await expectLater(
        manual.approve(rejected, actor: 'test-admin', identityVerified: true),
        throwsA(isA<ApiError>()),
      );
      final unknown = await request('unknown@example.org');
      await expectLater(
        manual.approve(unknown, actor: 'test-admin', identityVerified: true),
        throwsA(isA<ApiError>()),
      );
      final inactive = await request();
      await auth.db.execute('UPDATE users SET active=0 WHERE id=?', [userId]);
      await expectLater(
        manual.approve(inactive, actor: 'test-admin', identityVerified: true),
        throwsA(isA<ApiError>()),
      );
    },
  );

  test(
    'concurrent approvals have only one winner and SQL performs a guarded reset',
    () async {
      final first = await request();
      final second = await request();
      final outcomes = await Future.wait([
        for (final id in [first, second])
          manual
              .approve(id, actor: 'test-admin', identityVerified: true)
              .then((_) => true)
              .catchError((_) => false),
      ]);
      expect(outcomes.where((ok) => ok).length, 1);
      final sqlRequest = await request();
      final sql = manualRecoveryApprovalSql(sqlRequest);
      expect(sql.contains(newPassword), isFalse);
      await auth.db.execute(sql);
      expect((await manual.inspect(sqlRequest))['status'], 'approved');
      await expectLater(auth.db.execute(sql), throwsA(anything));
      expect(
        () => manualRecoveryApprovalSql("'; DROP TABLE users;--"),
        throwsArgumentError,
      );
    },
  );

  test('v3 backup preserves requests and v2 remains importable', () async {
    final id = await request();
    final snapshot = await exportIdentity(auth);
    expect(snapshot['format'], 'semob-identity-v3');
    final destination = await PostgresFixture.create();
    addTearDown(destination.close);
    final target = await destination.open();
    await importIdentity(target, snapshot);
    expect(
      (await ManualRecoveryStore(target).inspect(id))['status'],
      'pending',
    );
    final oldDestination = await PostgresFixture.create();
    addTearDown(oldDestination.close);
    final oldTarget = await oldDestination.open();
    final old = Map<String, dynamic>.from(snapshot)
      ..['format'] = 'semob-identity-v2';
    old['tables'] = Map<String, dynamic>.from(snapshot['tables'] as Map)
      ..remove('manual_recovery_requests');
    await importIdentity(oldTarget, old);
    expect(await ManualRecoveryStore(oldTarget).list(), isEmpty);
  });

  test(
    'HTTP response is generic, operator cannot review, failed notifier retains request',
    () async {
      final temp = Directory.systemTemp.createTempSync('semob-manual-api-');
      final store = await LocalDocumentStore.open('${temp.path}/data.sembast');
      final notifier = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, dynamic>? notification;
      notifier.listen((r) async {
        notification =
            jsonDecode(await utf8.decoder.bind(r).join())
                as Map<String, dynamic>;
        r.response.statusCode = 503;
        await r.response.close();
      });
      addTearDown(() async {
        await notifier.close(force: true);
        await store.close();
        temp.deleteSync(recursive: true);
      });
      final api = SemobApi(
        DataService(store),
        auth,
        recoveryAdminWebhook: 'http://127.0.0.1:${notifier.port}/notify',
      );
      Future<Response> call(
        String method,
        String path, {
        Object? body,
        String? token,
      }) async => await api.handler(
        Request(
          method,
          Uri.parse('http://localhost/api/v1/$path'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      );
      Future<Map<String, dynamic>> parse(Response r) async =>
          jsonDecode(await r.readAsString()) as Map<String, dynamic>;
      final body = {
        'name': 'Pessoa',
        'identifier': 'person@example.org',
        'password': newPassword,
        'passwordConfirmation': newPassword,
      };
      final knownResponse = await call(
        'POST',
        'auth/password-recovery/manual',
        body: body,
      );
      expect(knownResponse.statusCode, 202);
      final known = await parse(knownResponse);
      final unknown = await parse(
        await call(
          'POST',
          'auth/password-recovery/manual',
          body: {...body, 'identifier': 'missing@example.org'},
        ),
      );
      expect(known['message'], unknown['message']);
      expect(known.keys.toSet(), unknown.keys.toSet());
      expect(notification?['to'], 'omarsalibaescola@gmail.com');
      expect(jsonEncode(notification).contains(newPassword), isFalse);
      final records = await manual.list();
      expect(
        records.every((r) => r['notification_status'] == 'failed'),
        isTrue,
      );
      final token =
          (await auth.login('pessoa', oldPassword))['token'] as String;
      expect((await call('GET', 'access-requests')).statusCode, 401);
      expect(
        (await call('GET', 'access-requests', token: token)).statusCode,
        403,
      );
      expect(
        (await call(
          'POST',
          'access-requests/${known['requestId']}/approve',
          token: token,
          body: {'identityVerified': true},
        )).statusCode,
        403,
      );
      final admin = await auth.createUser({
        'name': 'Admin',
        'email': 'admin@example.org',
        'password': oldPassword,
        'accessLevel': 'administrator',
      });
      final adminToken =
          (await auth.login(admin['email'] as String, oldPassword))['token']
              as String;
      final listed = await parse(
        await call('GET', 'access-requests', token: adminToken),
      );
      expect(jsonEncode(listed).contains('proposed_hash'), isFalse);
      expect(
        (await call(
          'POST',
          'access-requests/${known['requestId']}/approve',
          token: adminToken,
          body: {'identityVerified': true},
        )).statusCode,
        200,
      );
    },
  );
}
