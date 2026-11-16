import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../providers/app_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/user_avatar.dart';
import '../widgets/module_tabs.dart';
import '../widgets/account_layout.dart' show accountSections;
import 'navigation_model.dart';
export 'navigation_model.dart' show navigation;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool hovered = false, keyboardFocus = false, opened = false;
  String? expandedGroup;
  Timer? closeTimer;
  final sidebarFocus = FocusNode(debugLabel: 'Menu SEMOB');
  @override
  void dispose() {
    closeTimer?.cancel();
    sidebarFocus.dispose();
    super.dispose();
  }

  void closeLater() {
    closeTimer?.cancel();
    closeTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && !sidebarFocus.hasFocus) {
        setState(() {
          hovered = false;
          opened = false;
        });
      }
    });
  }

  Future<void> savePreference(Map<String, dynamic> change) async {
    try {
      await ref.read(preferencesProvider.notifier).save(change);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a preferência. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    final ok = await ref.read(authProvider.notifier).signOut();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível sair. Verifique a conexão.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final path = GoRouterState.of(context).uri.path;
    final entries = navigation.where((e) => user.can(e.permission)).toList();
    final groups = [
      for (final g in navigationGroups)
        if (g.children.any((e) => user.can(e.permission)))
          NavGroup(
            g.label,
            g.icon,
            g.children.where((e) => user.can(e.permission)).toList(),
          ),
    ];
    final active = entries.where((e) => e.matches(path)).firstOrNull;
    final group = groups
        .where((g) => g.children.any((e) => e.matches(path)))
        .firstOrNull;
    final pinned =
        ref.watch(preferencesProvider).value?['sidebarPinned'] == true;
    final mobile = AppBreakpoints.isMobile(context);
    final expanded = pinned || hovered || keyboardFocus || opened;

    Widget profileMenu() => PopupMenuButton<String>(
      tooltip: 'Menu do perfil',
      onSelected: (v) => v == 'logout' ? logout() : context.go(v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: '/profile', child: Text('Meu perfil')),
        PopupMenuItem(value: '/settings', child: Text('Configurações')),
        PopupMenuItem(value: 'logout', child: Text('Sair')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: UserAvatar(user: user, radius: 17),
      ),
    );

    Future<void> showMenu() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(padding: EdgeInsets.all(12), child: BrandMark()),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Text(
                    g.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.7,
                      color: context.palette.muted,
                    ),
                  ),
                ),
                for (final e in g.children)
                  ListTile(
                    selected: e.matches(path),
                    leading: Icon(e.icon),
                    title: Text(e.label),
                    onTap: () {
                      Navigator.pop(sheet);
                      context.go(e.path);
                    },
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () {
                  Navigator.pop(sheet);
                  logout();
                },
              ),
            ],
          ),
        ),
      ),
    );

    Widget topbar() => Container(
      margin: EdgeInsets.fromLTRB(mobile ? 12 : 24, 16, mobile ? 12 : 24, 0),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 18, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: .93),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.line.withValues(alpha: .65)),
      ),
      child: Row(
        children: [
          if (mobile)
            IconButton(
              tooltip: 'Abrir navegação',
              onPressed: showMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!mobile)
                  Text(
                    'SEMOB  /  ${group?.label ?? 'Portal'}',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                Text(
                  active?.label ?? 'Portal SEMOB',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (!mobile &&
              ![
                '/settings',
                '/profile',
                '/users',
                '/access-requests',
                '/help',
              ].contains(path)) ...[
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: context.palette.muted,
            ),
            const SizedBox(width: 8),
            Text(
              ref.watch(globalFiltersProvider).period,
              style: TextStyle(color: context.palette.muted, fontSize: 12),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Atualizar dados',
              onPressed: () => refreshData(ref),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
          IconButton(
            tooltip: 'Alternar tema',
            onPressed: () => savePreference({
              'theme': context.palette.isDark ? 'light' : 'dark',
            }),
            icon: Icon(
              context.palette.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
          if (!mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 1,
                height: 24,
                color: context.palette.line,
              ),
            ),
          if (MediaQuery.sizeOf(context).width > 1100)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                user.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          profileMenu(),
        ],
      ),
    );

    final dockEntries = path == '/settings' || path == '/profile'
        ? <DockDestination>[
            for (final section in accountSections)
              (
                path: section.key == 'profile'
                    ? '/profile'
                    : '/settings?tab=${section.key}',
                label: section.label,
                icon: section.icon,
              ),
          ]
        : <DockDestination>[
            for (final e
                in (group != null && group.children.length > 1
                    ? group.children
                    : [for (final g in groups) g.children.first]))
              (path: e.path, label: e.label, icon: e.icon),
          ];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topbar(),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: RepaintBoundary(child: widget.child)),
              Positioned(
                left: mobile ? 12 : 28,
                right: mobile ? 12 : 28,
                bottom: 18,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    child: ModuleTabs(destinations: dockEntries),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (mobile) {
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
      final selected = direct.indexWhere((e) => e.matches(path));
      return Scaffold(
        body: SafeArea(child: content),
        bottomNavigationBar: NavigationBar(
          height: 70,
          selectedIndex: selected < 0 ? direct.length : selected,
          destinations: [
            for (final e in direct)
              NavigationDestination(
                icon: Icon(e.icon),
                label: switch (e.path) {
                  '/dashboard' => 'Início',
                  '/operation' => 'Operação',
                  '/assistant' => 'IA',
                  _ => e.label,
                },
              ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Mais',
            ),
          ],
          onDestinationSelected: (i) {
            if (i < direct.length) {
              context.go(direct[i].path);
            } else {
              showMenu();
            }
          },
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.palette.canvas,
              context.palette.surface,
              context.palette.canvas,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              left: 16 + (pinned ? DesignTokens.sidebar : DesignTokens.rail),
              child: content,
            ),
            Positioned(
              left: 16,
              top: 16,
              bottom: 16,
              child: Focus(
                focusNode: sidebarFocus,
                onFocusChange: (value) {
                  if (mounted) setState(() => keyboardFocus = value);
                  if (!value) closeLater();
                },
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    sidebarFocus.unfocus();
                    setState(() {
                      hovered = false;
                      keyboardFocus = false;
                      opened = false;
                    });
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  key: const Key('floating_sidebar'),
                  onEnter: (_) {
                    closeTimer?.cancel();
                    setState(() => hovered = true);
                  },
                  onExit: (_) => closeLater(),
                  child: AnimatedContainer(
                    key: const Key('sidebar_width'),
                    duration: DesignTokens.motion(
                      context,
                      DesignTokens.navigation,
                    ),
                    curve: DesignTokens.curve,
                    width: expanded ? DesignTokens.sidebar : DesignTokens.rail,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppColors.sage.withValues(alpha: .3),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.forest, AppColors.forestBlack],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .16),
                          blurRadius: 30,
                          offset: const Offset(6, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final labels = expanded && c.maxWidth > 220;
                        return Column(
                          children: [
                            SizedBox(
                              height: 85,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (labels)
                                    const Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(left: 18),
                                        child: BrandMark(
                                          onDark: true,
                                          compact: false,
                                        ),
                                      ),
                                    )
                                  else
                                    const BrandMark(
                                      onDark: true,
                                      compact: true,
                                    ),
                                  if (labels)
                                    IconButton(
                                      key: const Key('sidebar_pin'),
                                      tooltip: pinned
                                          ? 'Desafixar menu'
                                          : 'Fixar menu aberto',
                                      onPressed: () => savePreference({
                                        'sidebarPinned': !pinned,
                                      }),
                                      icon: Icon(
                                        pinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        color: AppColors.softSage,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Divider(
                                height: 1,
                                color: AppColors.sage.withValues(alpha: .25),
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 16,
                                ),
                                children: [
                                  for (final g in groups) ...[
                                    _NavTile(
                                      label: g.label,
                                      icon: g.icon,
                                      active:
                                          g == group ||
                                          g.children.any(
                                            (e) => e.matches(path),
                                          ),
                                      labels: labels,
                                      expanded:
                                          expandedGroup == g.label ||
                                          expandedGroup == null &&
                                              g.label == group?.label,
                                      onTap: () {
                                        if (!labels) {
                                          context.go(g.children.first.path);
                                          setState(() {
                                            opened = true;
                                            expandedGroup = g.label;
                                          });
                                        } else if (g.children.length == 1) {
                                          context.go(g.children.first.path);
                                        } else {
                                          final isOpen =
                                              expandedGroup == g.label ||
                                              expandedGroup == null &&
                                                  g.label == group?.label;
                                          setState(
                                            () => expandedGroup = isOpen
                                                ? ''
                                                : g.label,
                                          );
                                        }
                                      },
                                      hasChildren: g.children.length > 1,
                                    ),
                                    if (labels && g.children.length > 1)
                                      AnimatedSize(
                                        duration: DesignTokens.motion(context),
                                        child:
                                            expandedGroup == g.label ||
                                                expandedGroup == null &&
                                                    g.label == group?.label
                                            ? Column(
                                                children: [
                                                  for (final e in g.children)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 18,
                                                          ),
                                                      child: _NavTile(
                                                        label: e.label,
                                                        icon: e.icon,
                                                        active: e.matches(path),
                                                        labels: true,
                                                        child: true,
                                                        onTap: () =>
                                                            context.go(e.path),
                                                      ),
                                                    ),
                                                ],
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    const SizedBox(height: 6),
                                  ],
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                              child: Column(
                                children: [
                                  if (labels)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.lime.withValues(
                                          alpha: .07,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.eco_outlined,
                                            color: AppColors.lime,
                                            size: 19,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Inteligência para\nmover a cidade.',
                                              style: TextStyle(
                                                color: AppColors.softSage,
                                                fontSize: 11,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _NavTile(
                                    label: 'Sair',
                                    icon: Icons.logout_rounded,
                                    active: false,
                                    labels: labels,
                                    onTap: logout,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.labels,
    required this.onTap,
    this.hasChildren = false,
    this.expanded = false,
    this.child = false,
  });
  final String label;
  final IconData icon;
  final bool active, labels, hasChildren, expanded, child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: labels ? '' : label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: DesignTokens.motion(context),
          constraints: const BoxConstraints(minHeight: 46),
          padding: EdgeInsets.symmetric(
            horizontal: labels ? 13 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.lime.withValues(alpha: child ? .09 : .16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: labels
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? AppColors.lime : AppColors.softSage,
                size: child ? 16 : 20,
              ),
              if (labels) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.ivory : AppColors.softSage,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: child ? 11 : 12,
                    ),
                  ),
                ),
                if (hasChildren)
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.softSage,
                    size: 16,
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
