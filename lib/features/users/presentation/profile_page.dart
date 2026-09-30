import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../mocks/mock_users.dart';
import '../../../models/user.dart';
import '../../../shared/widgets/page_components.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(
      children: [
        const PageHeader(
          title: 'Meu Perfil',
          subtitle: 'Dados funcionais e permissões da conta',
        ),
        const SizedBox(height: 16),
        TwoColumnLayout(
          leftFlex: 2,
          rightFlex: 1,
          left: SectionCard(
            title: 'Dados do funcionário',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.greenLight,
                      child: Text(
                        'MO',
                        style: TextStyle(
                          color: AppColors.greenDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser.identifier,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(label: 'Ativo'),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 10),
                _ProfileRow(label: 'Cargo', value: currentUser.role),
                _ProfileRow(label: 'Setor', value: currentUser.department),
                _ProfileRow(
                  label: 'Nível de acesso',
                  value: currentUser.accessLevel.label,
                ),
                _ProfileRow(
                  label: 'Último acesso',
                  value: currentUser.lastAccess,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Permissões resumidas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Permission(
                  icon: Icons.visibility_outlined,
                  label: 'Visualizar todos os painéis',
                ),
                const _Permission(
                  icon: Icons.download_outlined,
                  label: 'Exportar relatórios',
                ),
                const _Permission(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Gerenciar usuários',
                ),
                const _Permission(
                  icon: Icons.settings_outlined,
                  label: 'Configurar o sistema',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.tune, size: 17),
                  label: const Text('Preferências'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).signOut();
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout, size: 17),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}

class _Permission extends StatelessWidget {
  const _Permission({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.green, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );
}
