import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/api.dart';
import 'package:semob_backend/auth_store.dart';
import 'package:semob_backend/data_service.dart';
import 'package:semob_backend/dataset_importer.dart';
import 'package:semob_backend/document_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'postgres_fixture.dart';

void main() {
  late Directory temporary;
  late AuthStore auth;
  late LocalDocumentStore store;
  late SemobApi api;
  late String token;
  late String adminId;
  late PostgresFixture postgres;
  Future<Response> call(
    String method,
    String path, {
    Object? body,
    String? bearer,
    bool authenticated = true,
    Map<String, String> headers = const {},
  }) async => await api.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        'Content-Type': 'application/json',
        if (authenticated) 'Authorization': 'Bearer ${bearer ?? token}',
        ...headers,
      },
      body: body == null ? null : jsonEncode(body),
    ),
  );
  Future<Map<String, dynamic>> object(Response r) async =>
      Map<String, dynamic>.from(jsonDecode(await r.readAsString()) as Map);
  setUpAll(() async {
    temporary = Directory.systemTemp.createTempSync('semob-api-test-');
    postgres = await PostgresFixture.create();
    auth = await postgres.open();
    store = await LocalDocumentStore.open(
      '${temporary.path}/transport.sembast',
    );
    final user = await auth.createUser({
      'name': 'Admin',
      'email': 'admin@example.org',
      'identifier': '123',
      'password': 'test-password-12345',
      'accessLevel': 'administrator',
    });
    adminId = user['id'] as String;
    final importer = DatasetImporter(store);
    await importer.import(
      importer.parseCsv(
        'date,weekday,vehicles,max_vehicles_in_range,scheduled_trips,completed_trips,productive_km,unproductive_km,total_km\n2026-08-01,Sab,1,1,10,9,100,2,102\n',
        'operation_days',
        'ops.csv',
      ),
    );
    api = SemobApi(DataService(store), auth, exposeRecoveryCode: true);
    token = (await auth.login('123', 'test-password-12345'))['token'] as String;
  });
  tearDownAll(() async {
    await postgres.close();
    await store.close();
    temporary.deleteSync(recursive: true);
  });
  test('API requires sessions and validates payloads/periods', () async {
    expect(
      (await call('GET', '/api/v1/operation', authenticated: false)).statusCode,
      401,
    );
    expect(
      (await call(
        'POST',
        '/api/v1/auth/login',
        authenticated: false,
        body: [],
      )).statusCode,
      400,
    );
    expect(
      (await call(
        'POST',
        '/api/v1/auth/login',
        authenticated: false,
        body: {'identifier': 1, 'password': 'x'},
      )).statusCode,
      400,
    );
    expect(
      (await call('GET', '/api/v1/operation?period=2026-99')).statusCode,
      400,
    );
    expect(
      (await call('GET', '/api/v1/trips?period=2026-08&limit=0')).statusCode,
      400,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/operation?period=2026-08&from=2026-02-30',
      )).statusCode,
      400,
    );
    expect((await call('GET', '/ready', authenticated: false)).statusCode, 200);
  });
  test('login, profile and logout work with bearer and cookie', () async {
    final response = await call(
      'POST',
      '/api/v1/auth/login',
      authenticated: false,
      body: {
        'identifier': 'admin@example.org',
        'password': 'test-password-12345',
        'remember': true,
      },
    );
    expect(response.statusCode, 200);
    expect(response.headers['set-cookie'], contains('HttpOnly'));
    final body = await object(response);
    final session = body['token'] as String;
    expect(
      (await call('GET', '/api/v1/auth/me', bearer: session)).statusCode,
      200,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/auth/me',
        authenticated: false,
        headers: {'Cookie': 'semob_session=$session'},
      )).statusCode,
      200,
    );
    expect(
      (await call(
        'POST',
        '/api/v1/preferences',
        authenticated: false,
        headers: {'Cookie': 'semob_session=$session'},
        body: {},
      )).statusCode,
      403,
    );
    await call('POST', '/api/v1/auth/logout', bearer: session);
    expect(
      (await call('GET', '/api/v1/auth/me', bearer: session)).statusCode,
      401,
    );
  });
  test(
    'security boundaries reject foreign origins, oversized identifiers and bogus reset challenges',
    () async {
      expect(
        (await call(
          'GET',
          '/api/v1/users',
          headers: {'Origin': 'https://untrusted.example.org'},
        )).statusCode,
        403,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/auth/login',
          authenticated: false,
          body: {'identifier': 'x' * 251, 'password': 'irrelevant'},
        )).statusCode,
        400,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/auth/password-recovery/request',
          authenticated: false,
          body: {'email': 'bad', 'emailConfirmation': 'bad'},
        )).statusCode,
        400,
      );
      final invalidReset = await call(
        'POST',
        '/api/v1/auth/password-recovery/reset',
        authenticated: false,
        body: {
          'challengeId': 'unknown',
          'resetToken': 'invalid',
          'password': 'short',
        },
      );
      expect(invalidReset.statusCode, 400);
      expect(
        (await object(invalidReset))['message'],
        'Solicitação inválida ou expirada.',
      );
      expect((await auth.getUser(adminId))['active'], true);
    },
  );
  test(
    'user lifecycle enforces RBAC and preserves last administrator',
    () async {
      final created = await call(
        'POST',
        '/api/v1/users',
        body: {
          'name': 'Operador',
          'email': 'operator@example.org',
          'password': 'operator-password-123',
          'accessLevel': 'operator',
        },
      );
      expect(created.statusCode, 201);
      final user = await object(created);
      final session =
          (await auth.login(
                'operator@example.org',
                'operator-password-123',
              ))['token']
              as String;
      expect(
        (await call(
          'GET',
          '/api/v1/operation?period=2026-08',
          bearer: session,
        )).statusCode,
        200,
      );
      for (final path in [
        'users',
        'financial',
        'assistant/status',
        'exports/trips',
      ]) {
        expect(
          (await call(
            'GET',
            '/api/v1/$path?period=2026-08',
            bearer: session,
          )).statusCode,
          403,
        );
      }
      expect(
        (await call(
          'PATCH',
          '/api/v1/users/$adminId',
          body: {'accessLevel': 'operator'},
        )).statusCode,
        409,
      );
      expect(
        (await call(
          'PATCH',
          '/api/v1/users/${user['id']}',
          body: {'active': false},
        )).statusCode,
        200,
      );
      expect(
        (await call('GET', '/api/v1/auth/me', bearer: session)).statusCode,
        401,
      );
    },
  );
  test(
    'new CSV data does not modify identity DB, exports produce real CSV/PDF',
    () async {
      final before = (await auth.listUsers()).length;
      final upload = await call(
        'POST',
        '/api/v1/imports',
        body: {
          'filename': 'passengers.csv',
          'dataset': 'passenger_days',
          'content': base64Encode(
            utf8.encode(
              'date,turnstile,advance_sales,non_paying,total\n2026-08-01,1,2,3,6\n',
            ),
          ),
        },
      );
      expect(upload.statusCode, 201);
      expect((await auth.listUsers()).length, before);
      final response = await call(
        'GET',
        '/api/v1/exports/passengers?period=2026-08&format=csv',
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), contains('"6"'));
      final pdf = await call(
        'GET',
        '/api/v1/exports/passengers?period=2026-08&format=pdf',
      );
      expect(pdf.statusCode, 200);
      final bytes = await pdf.read().expand((r) => r).toList();
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      await call('PUT', '/api/v1/preferences', body: {'compact': true});
      expect(
        (await object(await call('GET', '/api/v1/preferences')))['compact'],
        true,
      );
    },
  );
  test(
    'recovery resets actual password, consumes challenge and revokes sessions',
    () async {
      final created = await auth.createUser({
        'name': 'Recover',
        'email': 'recover@example.org',
        'password': 'before-password-123',
        'accessLevel': 'analyst',
      });
      final old =
          (await auth.login(
                'recover@example.org',
                'before-password-123',
              ))['token']
              as String;
      final challenge = await object(
        await call(
          'POST',
          '/api/v1/auth/password-recovery/request',
          authenticated: false,
          body: {
            'email': 'recover@example.org',
            'emailConfirmation': 'recover@example.org',
          },
        ),
      );
      final verified = await object(
        await call(
          'POST',
          '/api/v1/auth/password-recovery/verify',
          authenticated: false,
          body: {
            'challengeId': challenge['challengeId'],
            'code': challenge['developmentCode'],
          },
        ),
      );
      final reset = {
        'challengeId': challenge['challengeId'],
        'resetToken': verified['resetToken'],
        'password': 'after-password-123',
      };
      expect(
        (await call(
          'POST',
          '/api/v1/auth/password-recovery/reset',
          authenticated: false,
          body: reset,
        )).statusCode,
        200,
      );
      expect(await auth.authenticate(old), null);
      expect(
        (await call(
          'POST',
          '/api/v1/auth/password-recovery/reset',
          authenticated: false,
          body: reset,
        )).statusCode,
        400,
      );
      expect(
        (await auth.login(
          'recover@example.org',
          'after-password-123',
        ))['user']['id'],
        created['id'],
      );
    },
  );
  test(
    'external IA API receives scoped aggregates and server credential',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      server.listen((r) async {
        expect(r.headers.value('authorization'), 'Bearer test-external-key');
        requests.add(
          jsonDecode(await utf8.decoder.bind(r).join()) as Map<String, dynamic>,
        );
        r.response.headers.contentType = ContentType.json;
        r.response.write(
          jsonEncode({'answer': 'Resposta real do serviço de teste'}),
        );
        await r.response.close();
      });
      try {
        api = SemobApi(
          DataService(store),
          auth,
          aiUrl: 'http://127.0.0.1:${server.port}/chat',
          aiKey: 'test-external-key',
        );
        final response = await call(
          'POST',
          '/api/v1/assistant',
          body: {
            'message': 'Como foi a operação?',
            'filters': {'period': '2026-08'},
          },
        );
        expect(response.statusCode, 200);
        expect(
          (await object(response))['answer'],
          contains('serviço de teste'),
        );
        expect(requests.single['context']['period'], '2026-08');
        expect(requests.single.containsKey('user'), false);
      } finally {
        await server.close(force: true);
        api = SemobApi(DataService(store), auth);
      }
      expect(
        (await call(
          'POST',
          '/api/v1/assistant',
          body: {'message': 'teste'},
        )).statusCode,
        503,
      );
    },
  );
}
