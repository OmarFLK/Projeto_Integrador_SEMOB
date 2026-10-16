import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/user_avatar.dart';

const navigation = [
  (
    label: 'Visão Geral',
    path: '/dashboard',
    icon: Icons.space_dashboard_outlined,
    permission: 'read',
  ),
  (
    label: 'Operação',
    path: '/operation',
    icon: Icons.route_outlined,
    permission: 'read',
  ),
  (label: 'Viagens', path: '/trips', icon: Icons.alt_route, permission: 'read'),
  (
    label: 'Passageiros',
    path: '/passengers',
    icon: Icons.groups_outlined,
    permission: 'read',
  ),
  (
    label: 'Linhas',
    path: '/lines',
    icon: Icons.signpost_outlined,
    permission: 'read',
  ),
  (
    label: 'Frota',
    path: '/fleet',
    icon: Icons.directions_bus_outlined,
    permission: 'read',
  ),
  (
    label: 'Financeiro',
    path: '/financial',
    icon: Icons.account_balance_wallet_outlined,
    permission: 'financial',
  ),
  (
    label: 'Anomalias',
    path: '/anomalies',
    icon: Icons.warning_amber,
    permission: 'read',
  ),
  (
    label: 'Insights',
    path: '/insights',
    icon: Icons.lightbulb_outline,
    permission: 'read',
  ),
  (
    label: 'Assistente IA',
    path: '/assistant',
    icon: Icons.auto_awesome,
    permission: 'assistant',
  ),
  (
    label: 'Relatórios e dados',
    path: '/reports',
    icon: Icons.description_outlined,
    permission: 'export',
  ),
  (
    label: 'Usuários e Acessos',
    path: '/users',
    icon: Icons.manage_accounts_outlined,
    permission: 'users',
  ),
  (
    label: 'Configurações',
    path: '/settings',
    icon: Icons.settings_outlined,
    permission: 'read',
  ),
  (label: 'Ajuda', path: '/help', icon: Icons.help_outline, permission: 'read'),
  (
    label: 'Meu Perfil',
    path: '/profile',
    icon: Icons.person_outline,
    permission: 'read',
  ),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final entries = navigation.where((r) => user.can(r.permission)).toList();
    final path = GoRouterState.of(context).uri.path;
    final title =
        entries
            .where((r) => path == r.path || path.startsWith('${r.path}/'))
            .firstOrNull
            ?.label ??
        'Portal SEMOB';
    Widget profile() => PopupMenuButton<String>(
      tooltip: 'Menu do perfil',
      onSelected: (v) async {
        if (v == 'logout') {
          final success = await ref.read(authProvider.notifier).signOut();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Não foi possível sair. Verifique a conexão e tente novamente.',
                ),
              ),
            );
          }
        } else {
          context.go(v);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: '/profile', child: Text('Meu perfil')),
        PopupMenuItem(value: '/settings', child: Text('Configurações')),
        PopupMenuItem(value: 'logout', child: Text('Sair')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: UserAvatar(user: user, radius: 18),
      ),
    );
    if (AppBreakpoints.isMobile(context)) {
      final direct = entries
          .where(
            (e) => [
              '/dashboard',
              '/operation',
              '/insights',
              '/assistant',
            ].contains(e.path),
          )
          .toList();
      final index = direct.indexWhere((e) => e.path == path);
      return Scaffold(
        appBar: AppBar(
          title: const BrandMark(compact: true),
          actions: [profile()],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index < 0 ? direct.length : index,
          destinations: [
            for (final e in direct)
              NavigationDestination(
                icon: Icon(e.icon),
                label: e.label == 'Visão Geral' ? 'Início' : e.label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Mais',
            ),
          ],
          onDestinationSelected: (i) {
            if (i < direct.length) {
              context.go(direct[i].path);
            } else {
              showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (modal) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * .75,
                  child: ListView(
                    children: [
                      for (final e in entries)
                        ListTile(
                          leading: Icon(e.icon),
                          title: Text(e.label),
                          onTap: () {
                            Navigator.pop(modal);
                            context.go(e.path);
                          },
                        ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      );
    }
    final compact = AppBreakpoints.isTablet(context);
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: compact ? 76 : 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF16382A),
                  Color(0xFF10251B),
                  Color(0xFF192920),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: BrandMark(onDark: true, compact: compact),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final e in entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color:
                                  path == e.path ||
                                      path.startsWith('${e.path}/')
                                  ? AppColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: compact
                                  ? IconButton(
                                      tooltip: e.label,
                                      onPressed: () => context.go(e.path),
                                      icon: Icon(e.icon, color: Colors.white70),
                                    )
                                  : ListTile(
                                      dense: true,
                                      leading: Icon(
                                        e.icon,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      title: Text(
                                        e.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onTap: () => context.go(e.path),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: context.palette.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!compact)
                        Text(user.name, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      profile(),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
