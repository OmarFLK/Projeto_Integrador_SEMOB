import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../services/api_client.dart';

class AccessRequestsPage extends ConsumerStatefulWidget {
  const AccessRequestsPage({super.key});
  @override
  ConsumerState<AccessRequestsPage> createState() => _RequestsState();
}

class _RequestsState extends ConsumerState<AccessRequestsPage> {
  String status = 'pending';
  final busy = <String>{};
  static const statusLabels = {
    'pending': 'Pendentes',
    'approved': 'Aprovadas',
    'rejected': 'Rejeitadas',
    'expired': 'Expiradas',
    'cancelled': 'Canceladas',
  };
  String get endpoint => 'access-requests?status=$status';
  String date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '—'
        : DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  Future<void> process(Map<String, dynamic> row, bool approve) async {
    var verified = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            approve ? 'Aprovar recuperação?' : 'Rejeitar solicitação?',
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approve
                      ? 'A senha proposta será aplicada a ${row['account_email']}. As sessões anteriores serão encerradas.'
                      : 'Este pedido será encerrado e a senha atual será mantida.',
                ),
                if (approve)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: verified,
                    onChanged: (v) => update(() => verified = v == true),
                    title: const Text(
                      'Confirmei a identidade por um canal previamente conhecido.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: approve && !verified
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: Text(approve ? 'Aprovar e redefinir' : 'Rejeitar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = row['id'] as String;
    setState(() => busy.add(id));
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post<void>(
            'access-requests/${Uri.encodeComponent(id)}/${approve ? 'approve' : 'reject'}',
            data: {'identityVerified': verified},
          );
      ref.invalidate(remoteProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Senha redefinida e sessões encerradas.'
                  : 'Solicitação rejeitada.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = ref.watch(remoteProvider(endpoint));
    return PageBody(
      children: [
        const PageHeader(
          title: 'Solicitações de acesso',
          subtitle: 'Revisão de identidade e recuperação de contas',
        ),
        const SizedBox(height: 20),
        const SemobHeroPanel(
          eyebrow: 'Administração / Segurança',
          title: 'Acesso com responsabilidade.',
          description:
              'Confira a identidade por um canal conhecido antes de aprovar. O nome e o acesso informados no pedido não são uma comprovação de identidade.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in statusLabels.entries)
              ChoiceChip(
                selected: status == entry.key,
                label: Text(entry.value),
                onSelected: (_) => setState(() => status = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        response.when(
          loading: () => const SemobLoadingSkeleton(),
          error: (e, _) => SemobEmptyState(
            message: apiError(e),
            icon: Icons.cloud_off_outlined,
            action: TextButton(
              onPressed: () => ref.invalidate(remoteProvider(endpoint)),
              child: const Text('Tentar novamente'),
            ),
          ),
          data: (data) {
            final rows = (data['items'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data['notificationConfigured'] != true)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: DataSourceNote(
                      text:
                          'Avisos automáticos não configurados. Os pedidos ficam disponíveis nesta fila para revisão manual.',
                      provisional: true,
                    ),
                  ),
                if (rows.isEmpty)
                  const SemobEmptyState(
                    message: 'Nenhuma solicitação neste status.',
                    icon: Icons.verified_user_outlined,
                  ),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SemobGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge(
                                label:
                                    statusLabels[row['status']] ??
                                    row['status'].toString(),
                                kind: row['status'] == 'pending'
                                    ? StatusKind.warning
                                    : StatusKind.neutral,
                              ),
                              Text(
                                date(row['created_at']),
                                style: TextStyle(
                                  color: context.palette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            row['account_name'] as String? ??
                                'Conta não localizada',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Nome declarado: ${row['declared_name']}'),
                          Text('Acesso informado: ${row['identifier']}'),
                          if (row['account_email'] != null)
                            Text('Conta vinculada: ${row['account_email']}'),
                          const SizedBox(height: 12),
                          Text(
                            'Validade: ${date(row['expires_at'])}',
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Protocolo: ${row['id']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.palette.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copiar protocolo',
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: row['id'] as String),
                                ),
                                icon: const Icon(Icons.copy_outlined, size: 16),
                              ),
                            ],
                          ),
                          if (row['status'] == 'pending')
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed:
                                      busy.contains(row['id']) ||
                                          row['account_active'] != 1
                                      ? null
                                      : () => process(row, true),
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Revisar e aprovar'),
                                ),
                                OutlinedButton(
                                  onPressed: busy.contains(row['id'])
                                      ? null
                                      : () => process(row, false),
                                  child: const Text('Rejeitar'),
                                ),
                              ],
                            ),
                          if (busy.contains(row['id']))
                            const LinearProgressIndicator(),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
