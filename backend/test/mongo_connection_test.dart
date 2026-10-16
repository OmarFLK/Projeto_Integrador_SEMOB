import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:semob_backend/document_store.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Atlas safety preserves TLS, database, escaped password and auth source',
    () {
      final uri = Uri.parse(
        normalizeMongoUrl(
          'mongodb+srv://app:p%40ss@cluster.mongodb.net/semob_data'
          '?authSource=admin&tls=true&safeAtlas=false&retryWrites=true',
        ),
      );
      expect(uri.userInfo, 'app:p%40ss');
      expect(uri.path, '/semob_data');
      expect(uri.queryParameters['safeAtlas'], 'true');
      expect(uri.queryParameters['tls'], 'true');
      expect(uri.queryParameters['authSource'], 'admin');
      expect(uri.queryParameters['retryWrites'], 'true');
    },
  );

  test('reconnect only connection failures, never auth or query errors', () {
    expect(
      isMongoConnectionError(mongo.MongoDartError('No master connection')),
      isTrue,
    );
    expect(
      isMongoConnectionError(
        mongo.MongoDartError('Primary changed', mongoCode: 10107),
      ),
      isTrue,
    );
    expect(
      isMongoConnectionError(const mongo.ConnectionException('closed')),
      isTrue,
    );
    expect(isMongoConnectionError(const SocketException('closed')), isTrue);
    expect(
      isMongoConnectionError(
        mongo.MongoDartError('Unauthorized', mongoCode: 13),
      ),
      isFalse,
    );
    expect(
      isMongoConnectionError(
        mongo.MongoDartError('Invalid pipeline', mongoCode: 2),
      ),
      isFalse,
    );
    expect(isMongoConnectionError(StateError('Invalid document')), isFalse);
  });
}
