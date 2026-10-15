import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const PageHeader(
        title: 'Configurações',
        subtitle: 'Preferências da sua conta',
      ),
      const SizedBox(height: 16),
      ref
          .watch(preferencesProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => TextButton(
              onPressed: () => ref.invalidate(preferencesProvider),
              child: const Text('Recarregar preferências'),
            ),
            data: (prefs) => SectionCard(
              title: 'Aparência',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo compacto'),
                subtitle: const Text('Reduz o espaçamento das páginas'),
                value: prefs['compact'] == true,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(apiClientProvider)
                        .dio
                        .put<void>('preferences', data: {'compact': value});
                    ref.invalidate(preferencesProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(apiError(e))));
                    }
                  }
                },
              ),
            ),
          ),
    ],
  );
}
