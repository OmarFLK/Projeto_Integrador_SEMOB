import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'errors.dart';

const maxAvatarUploadBytes = 1536 * 1024;
bool _processingAvatar = false;

Future<Uint8List> prepareAvatar(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > maxAvatarUploadBytes) {
    throw const ApiError(400, 'Escolha uma imagem PNG ou JPG de até 1,5 MB.');
  }
  if (_processingAvatar) {
    throw const ApiError(
      429,
      'Outra foto está sendo processada. Tente novamente em instantes.',
    );
  }
  _processingAvatar = true;
  try {
    final result = await Isolate.run(() => _normalizeAvatar(bytes));
    if (result == null) {
      throw const ApiError(
        400,
        'Imagem inválida. Use PNG ou JPG com até 4096 × 4096 pixels.',
      );
    }
    return result;
  } finally {
    _processingAvatar = false;
  }
}

Uint8List? _normalizeAvatar(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    if (decoder is! img.PngDecoder && decoder is! img.JpegDecoder) return null;
    final info = decoder!.startDecode(bytes);
    if (info == null ||
        info.width < 16 ||
        info.height < 16 ||
        info.width > 4096 ||
        info.height > 4096 ||
        info.numFrames != 1) {
      return null;
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) return null;
    final avatar = img.copyResizeCropSquare(
      img.bakeOrientation(decoded),
      size: 256,
      interpolation: img.Interpolation.average,
    );
    // Encode pixels only, discarding uploaded EXIF/text/profile metadata.
    final clean = img.Image(width: 256, height: 256, numChannels: 4);
    img.compositeImage(clean, avatar);
    return img.encodePng(clean);
  } catch (_) {
    return null;
  }
}
