import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:semob_backend/api.dart';
import 'package:semob_backend/data_service.dart';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/identity_transfer.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'postgres_fixture.dart';

void main() {
  test(
    'self-service account persists safely, including photo backup and sessions',
    () async {
      final fixture = await PostgresFixture.create();
      final restoredFixture = await PostgresFixture.create();
      final temp = Directory.systemTemp.createTempSync('semob-account-');
      final store = await LocalDocumentStore.open('${temp.path}/data.sembast');
      addTearDown(() async {
        await store.close();
        await fixture.close();
        await restoredFixture.close();
        temp.deleteSync(recursive: true);
      });
      final auth = await fixture.open();
      final user = await auth.createUser({
        'name': 'Operador',
        'email': 'operator@example.org',
        'identifier': 'operator',
        'password': 'old-test-password-12345',
        'accessLevel': 'operator',
      });
      final id = user['id'] as String;
      final token =
          (await auth.login('operator', 'old-test-password-12345'))['token']
              as String;
      final other =
          (await auth.login('operator', 'old-test-password-12345'))['token']
              as String;
      final api = SemobApi(DataService(store), auth);
      Future<Response> call(String method, String path, [Object? body]) async =>
          await api.handler(
            Request(
              method,
              Uri.parse('http://localhost/api/v1/$path'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: body == null ? null : jsonEncode(body),
            ),
          );
      Future<Map<String, dynamic>> object(Response response) async =>
          Map<String, dynamic>.from(
            jsonDecode(await response.readAsString()) as Map,
          );

      expect(
        (await call('PATCH', 'auth/profile', {
          'accessLevel': 'administrator',
        })).statusCode,
        400,
      );
      expect(
        (await call('PATCH', 'auth/profile', {
          'email': 'changed@example.org',
        })).statusCode,
        400,
      );
      final updated = await object(
        await call('PATCH', 'auth/profile', {
          'name': 'Nome atualizado',
          'email': 'changed@example.org',
          'jobTitle': 'Fiscal',
          'department': 'Operação',
          'currentPassword': 'old-test-password-12345',
        }),
      );
      expect(updated['name'], 'Nome atualizado');
      expect(updated['accessLevel'], 'operator');
      expect(updated.containsKey('password_hash'), false);
      expect((await call('GET', 'users')).statusCode, 403);

      expect(
        (await call('PUT', 'auth/avatar', {
          'url': 'https://example.org/photo.png',
        })).statusCode,
        400,
      );
      expect(
        (await call('PUT', 'auth/avatar', {
          'content': 'not base64',
        })).statusCode,
        400,
      );
      final photo = img.encodePng(img.Image(width: 80, height: 120));
      final photoUser = await object(
        await call('PUT', 'auth/avatar', {'content': base64Encode(photo)}),
      );
      expect(photoUser['avatarVersion'], isA<String>());
      expect(photoUser.containsKey('avatar_data'), false);
      final imageResponse = await call('GET', 'auth/avatar');
      expect(imageResponse.statusCode, 200);
      expect(
        img
            .decodePng(
              Uint8List.fromList(
                await imageResponse.read().expand((e) => e).toList(),
              ),
            )!
            .width,
        256,
      );
      await call('PUT', 'preferences', {
        'theme': 'dark',
        'aiTemperature': .4,
        'aiUseContext': false,
      });
      await call('PUT', 'preferences', {'compact': true});
      final secondProcess = await fixture.open();
      expect((await secondProcess.getUser(id))['name'], 'Nome atualizado');
      expect((await secondProcess.preferences(id))['theme'], 'dark');
      expect((await secondProcess.preferences(id))['compact'], true);
      expect(await secondProcess.avatar(id), isNotNull);

      final snapshot = await exportIdentity(auth);
      expect(snapshot['format'], 'semob-identity-v2');
      final restored = await restoredFixture.open();
      await importIdentity(restored, snapshot);
      expect(await restored.avatar(id), await auth.avatar(id));
      expect((await restored.preferences(id))['aiUseContext'], false);
      expect(
        (await restored.getUser(id))['avatarVersion'],
        photoUser['avatarVersion'],
      );
      expect((await call('DELETE', 'auth/avatar')).statusCode, 200);
      expect(await secondProcess.avatar(id), null);
      expect((await call('GET', 'auth/avatar')).statusCode, 404);

      final passwordBody = {
        'currentPassword': 'wrong-password',
        'password': 'new-test-password-12345',
        'passwordConfirmation': 'new-test-password-12345',
      };
      expect(
        (await call('POST', 'auth/password', passwordBody)).statusCode,
        400,
      );
      expect(await auth.authenticate(other), isNotNull);
      passwordBody['currentPassword'] = 'old-test-password-12345';
      expect(
        (await call('POST', 'auth/password', passwordBody)).statusCode,
        200,
      );
      expect(await auth.authenticate(other), null);
      expect(await auth.authenticate(token), isNotNull);
      final nextSession =
          (await auth.login('operator', 'new-test-password-12345'))['token']
              as String;
      expect((await object(await call('GET', 'auth/sessions')))['active'], 2);
      await call('POST', 'auth/sessions/revoke-others');
      expect(await auth.authenticate(nextSession), null);
      expect(await auth.authenticate(token), isNotNull);
    },
  );
}
