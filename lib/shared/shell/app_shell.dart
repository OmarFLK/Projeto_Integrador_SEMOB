import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../mocks/mock_users.dart';
import '../../models/user.dart';
import '../widgets/brand_mark.dart';

class NavigationEntry {
  const NavigationEntry(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}

const primaryNavigation = <NavigationEntry>[
  NavigationEntry('Visão Geral', '/dashboard', Icons.space_dashboard_outlined),
  NavigationEntry('Operação', '/operation', Icons.route_outlined),
  NavigationEntry('Viagens', '/trips', Icons.alt_route_rounded),
  NavigationEntry('Passageiros', '/passengers', Icons.groups_2_outlined),
  NavigationEntry('Linhas', '/lines', Icons.signpost_outlined),
  NavigationEntry('Frota', '/fleet', Icons.directions_bus_outlined),
  NavigationEntry(
    'Financeiro',
    '/financial',
    Icons.account_balance_wallet_outlined,
  ),
  NavigationEntry('Anomalias', '/anomalies', Icons.warning_amber_rounded),
  NavigationEntry('Insights', '/insights', Icons.lightbulb_outline_rounded),
  NavigationEntry('Assistente IA', '/assistant', Icons.auto_awesome_outlined),
  NavigationEntry('Relatórios', '/reports', Icons.description_outlined),
  NavigationEntry(
    'Usuários e Acessos',
    '/users',
    Icons.manage_accounts_outlined,
  ),
];

const secondaryNavigation = <NavigationEntry>[
  NavigationEntry('Configurações', '/settings', Icons.settings_outlined),
  NavigationEntry('Ajuda', '/help', Icons.help_outline_rounded),
  NavigationEntry('Meu Perfil', '/profile', Icons.person_outline_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    if (AppBreakpoints.isMobile(context)) {
      return _MobileShell(path: path, child: child);
    }
    if (AppBreakpoints.isTablet(context)) {
      return _TabletShell(path: path, child: child);
    }
    return _DesktopShell(path: path, child: child);
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _NavigationPanel(path: path),
          Expanded(
            child: Column(
              children: [
                _TopBar(path: path),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: child),
                      if (path != '/assistant')
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: FloatingActionButton.extended(
                            heroTag: 'desktop_ai',
                            onPressed: () => context.go('/assistant'),
                            backgroundColor: AppColors.graphite,
                            foregroundColor: AppColors.white,
                            icon: const Icon(Icons.auto_awesome, size: 19),
                            label: const Text('Assistente SEMOB'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletShell extends StatelessWidget {
  const _TabletShell({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 76,
            color: AppColors.charcoal,
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: BrandMark(onDark: true, compact: true),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      children: [
                        for (final item in primaryNavigation)
                          _RailItem(
                            item: item,
                            selected: _selected(path, item.path),
                          ),
                      ],
                    ),
                  ),
                  _RailItem(
                    item: secondaryNavigation.last,
                    selected: _selected(path, '/profile'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(path: path),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.path, required this.child});

  final String path;
  final Widget child;

  static const bottomEntries = [
    NavigationEntry('Início', '/dashboard', Icons.home_outlined),
    NavigationEntry('Operação', '/operation', Icons.route_outlined),
    NavigationEntry('Insights', '/insights', Icons.lightbulb_outline),
    NavigationEntry('IA', '/assistant', Icons.auto_awesome_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final directIndex = bottomEntries.indexWhere(
      (item) => _selected(path, item.path),
    );
    final selected = directIndex < 0 ? 4 : directIndex;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        titleSpacing: 16,
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () =>
                _showMessage(context, 'Você não tem novas notificações.'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Meu perfil',
            onPressed: () => context.go('/profile'),
            icon: const CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.greenLight,
              child: Text(
                'MO',
                style: TextStyle(
                  color: AppColors.greenDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final item in bottomEntries)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
        ],
        onDestinationSelected: (index) {
          if (index < bottomEntries.length) {
            context.go(bottomEntries[index].path);
          } else {
            _openMore(context);
          }
        },
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.charcoal,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: BrandMark(onDark: true),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Text(
                      'NAVEGAÇÃO',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final item in primaryNavigation)
                    _SidebarItem(
                      item: item,
                      selected: _selected(path, item.path),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  for (final item in secondaryNavigation)
                    _SidebarItem(
                      item: item,
                      selected: _selected(path, item.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected});

  final NavigationEntry item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? AppColors.white : Colors.white60,
                  size: 19,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? AppColors.white : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.item, required this.selected});

  final NavigationEntry item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: selected ? AppColors.green : Colors.transparent,
            foregroundColor: selected ? AppColors.white : Colors.white60,
            minimumSize: const Size(48, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          onPressed: () => context.go(item.path),
          icon: Icon(item.icon, size: 21),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = [...primaryNavigation, ...secondaryNavigation]
        .where((item) => _selected(path, item.path))
        .map((item) => item.label)
        .firstOrNull;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text(
            title ?? 'Portal SEMOB',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notificações',
            onPressed: () =>
                _showMessage(context, 'Você não tem novas notificações.'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Menu do perfil',
            onSelected: (value) {
              if (value == 'profile') context.go('/profile');
              if (value == 'settings') context.go('/settings');
              if (value == 'logout') {
                ref.read(authProvider.notifier).signOut();
                context.go('/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Meu perfil')),
              PopupMenuItem(value: 'settings', child: Text('Preferências')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Sair')),
            ],
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.greenLight,
                  child: Text(
                    'MO',
                    style: TextStyle(
                      color: AppColors.greenDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currentUser.accessLevel.label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _selected(String current, String target) =>
    current == target || current.startsWith('$target/');

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _openMore(BuildContext context) {
  final moreEntries = [
    ...primaryNavigation.where(
      (item) => !const [
        '/dashboard',
        '/operation',
        '/insights',
        '/assistant',
      ].contains(item.path),
    ),
    ...secondaryNavigation,
  ];
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.76,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mais opções',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
              itemCount: moreEntries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = moreEntries[index];
                return ListTile(
                  leading: Icon(item.icon, color: AppColors.green),
                  title: Text(item.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    context.go(item.path);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
