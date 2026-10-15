import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../services/api_client.dart';
import '../../services/download.dart';
import '../providers/app_providers.dart';

Future<void> downloadDataset(
  BuildContext context,
  WidgetRef ref,
  String dataset, {
  bool template = true,
}) async {
  try {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<List<int>>(
          '${template ? 'templates' : 'normalized'}/$dataset',
          queryParameters: ref
              .read(globalFiltersProvider)
              .query(dimensions: false),
          options: Options(responseType: ResponseType.bytes),
        );
    await saveDownload(
      Uint8List.fromList(response.data!),
      '${template ? 'modelo_' : ''}$dataset.csv',
      'text/csv',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }
}

Future<void> exportResource(
  BuildContext context,
  WidgetRef ref,
  String resource,
  String format, {
  Map<String, String>? query,
}) async {
  try {
    final filters = ref.read(globalFiltersProvider);
    final defaults = {
      ...filters.query(dimensions: ['trips', 'vehicles'].contains(resource)),
      if (['lines', 'anomalies'].contains(resource) &&
          filters.line != 'Todas as linhas')
        'line': filters.line.replaceFirst('Linha ', ''),
    };
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<List<int>>(
          'exports/$resource',
          queryParameters: {...(query ?? defaults), 'format': format},
          options: Options(responseType: ResponseType.bytes),
        );
    await saveDownload(
      Uint8List.fromList(response.data!),
      'semob_${resource}_${filters.period}.$format',
      format == 'pdf' ? 'application/pdf' : 'text/csv',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }
}

class ExportActions extends ConsumerStatefulWidget {
  const ExportActions({super.key, required this.resource});
  final String resource;
  @override
  ConsumerState<ExportActions> createState() => _ExportActionsState();
}

class _ExportActionsState extends ConsumerState<ExportActions> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).user?.can('export') != true) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: [
        for (final format in ['csv', 'pdf'])
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await exportResource(context, ref, widget.resource, format);
                    if (mounted) setState(() => busy = false);
                  },
            child: Text(busy ? 'Aguarde...' : format.toUpperCase()),
          ),
      ],
    );
  }
}
