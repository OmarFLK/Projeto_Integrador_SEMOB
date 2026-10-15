import 'dart:convert';
import 'dart:io';
import 'package:semob_backend/document_store.dart';
import 'package:semob_backend/dataset_importer.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final DocumentStore store = env['SEMOB_MONGODB_URI'] == null
      ? await LocalDocumentStore.open(
          env['SEMOB_DOCUMENT_DATABASE'] ?? 'data/transport.sembast',
        )
      : await MongoDocumentStore.open(env['SEMOB_MONGODB_URI']!);
  try {
    final importer = DatasetImporter(store);
    final parsed = importer.parseArchive(
      await File(
        args.isEmpty ? 'data/semob_transport_reports.zip' : args[0],
      ).readAsBytes(),
    );
    final result = await importer.import(
      parsed,
      exportDirectory: args.length > 1 ? args[1] : 'data/exports',
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
  } finally {
    await store.close();
  }
}
