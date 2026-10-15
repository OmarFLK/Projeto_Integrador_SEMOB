import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

Future<void> saveDownload(Uint8List bytes, String filename, String mime) async {
  final location = await getSaveLocation(suggestedName: filename);
  if (location == null) return;
  await XFile.fromData(
    bytes,
    mimeType: mime,
    name: filename,
  ).saveTo(location.path);
}
