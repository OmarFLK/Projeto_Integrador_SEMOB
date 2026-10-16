import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:semob_backend/errors.dart';
import 'package:semob_backend/profile_image.dart';
import 'package:semob_backend/user_preferences.dart';
import 'package:test/test.dart';

void main() {
  test(
    'avatar validates bytes and stores a bounded image without metadata',
    () async {
      final source = img.Image(width: 480, height: 320, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(20, 100, 60, 255));
      final bytes = await prepareAvatar(img.encodePng(source));
      final result = img.decodePng(bytes)!;
      expect(result.width, 256);
      expect(result.height, 256);
      expect(bytes.length, lessThan(100000));
      await expectLater(
        prepareAvatar(
          Uint8List.fromList('<svg><script>bad()</script></svg>'.codeUnits),
        ),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        prepareAvatar(Uint8List(maxAvatarUploadBytes + 1)),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        prepareAvatar(img.encodePng(img.Image(width: 5000, height: 16))),
        throwsA(isA<ApiError>()),
      );
    },
  );
  test(
    'partial preferences preserve other settings and reject invalid generation controls',
    () {
      final prefs = validatePreferences(
        {'compact': true, 'theme': 'dark'},
        {'aiTemperature': .4, 'aiMaxTokens': 2400},
      );
      expect(prefs['compact'], true);
      expect(prefs['theme'], 'dark');
      expect(aiPreferences(prefs)['max_output_tokens'], 2400);
      for (final input in <Map<String, dynamic>>[
        {'theme': 'not-a-theme'},
        {'aiTemperature': double.nan},
        {'aiTemperature': 3},
        {'aiMaxTokens': -1},
        {'compact': 'true'},
        {'endpoint': 'https://untrusted.test'},
      ]) {
        expect(() => validatePreferences({}, input), throwsA(isA<ApiError>()));
      }
    },
  );
}
