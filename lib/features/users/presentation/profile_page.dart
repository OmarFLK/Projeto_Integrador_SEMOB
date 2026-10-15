import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../shared/widgets/page_components.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    return PageBody(
      children: [
        const PageHeader(
          title: 'Meu Perfil',
          subtitle: 'Identidade e permissões da sessão atual',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: user.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email),
              Text('Matrícula: ${user.identifier}'),
              Text('Cargo: ${user.role}'),
              Text('Setor: ${user.department}'),
              Text('Perfil: ${user.accessLevel.label}'),
              Text('Último acesso: ${user.lastAccess}'),
              const SizedBox(height: 12),
              Text('Permissões: ${user.permissions.join(', ')}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final success = await ref
                      .read(authProvider.notifier)
                      .signOut();
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Não foi possível sair. Tente novamente.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
