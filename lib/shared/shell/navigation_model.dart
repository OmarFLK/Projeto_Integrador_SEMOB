import 'package:flutter/material.dart';

class NavDestination {
  const NavDestination(
    this.label,
    this.path,
    this.icon, {
    this.permission = 'read',
  });
  final String label, path, permission;
  final IconData icon;
  bool matches(String route) => route == path || route.startsWith('$path/');
}

class NavGroup {
  const NavGroup(this.label, this.icon, this.children);
  final String label;
  final IconData icon;
  final List<NavDestination> children;
}

const navigationGroups = [
  NavGroup('Visão Geral', Icons.space_dashboard_outlined, [
    NavDestination('Visão Geral', '/dashboard', Icons.dashboard_outlined),
  ]),
  NavGroup('Operação', Icons.route_outlined, [
    NavDestination('Desempenho', '/operation', Icons.monitor_heart_outlined),
    NavDestination('Viagens', '/trips', Icons.alt_route),
    NavDestination('Linhas', '/lines', Icons.signpost_outlined),
    NavDestination('Frota', '/fleet', Icons.directions_bus_outlined),
  ]),
  NavGroup('Passageiros', Icons.groups_outlined, [
    NavDestination('Passageiros', '/passengers', Icons.groups_outlined),
  ]),
  NavGroup('Financeiro', Icons.account_balance_wallet_outlined, [
    NavDestination(
      'Financeiro',
      '/financial',
      Icons.account_balance_wallet_outlined,
      permission: 'financial',
    ),
  ]),
  NavGroup('Inteligência', Icons.auto_awesome_outlined, [
    NavDestination('Anomalias', '/anomalies', Icons.warning_amber_rounded),
    NavDestination('Insights', '/insights', Icons.lightbulb_outline),
    NavDestination(
      'Assistente IA',
      '/assistant',
      Icons.auto_awesome,
      permission: 'assistant',
    ),
  ]),
  NavGroup('Dados', Icons.layers_outlined, [
    NavDestination(
      'Relatórios e dados',
      '/reports',
      Icons.description_outlined,
      permission: 'export',
    ),
  ]),
  NavGroup('Administração', Icons.admin_panel_settings_outlined, [
    NavDestination(
      'Usuários e Acessos',
      '/users',
      Icons.manage_accounts_outlined,
      permission: 'users',
    ),
    NavDestination(
      'Solicitações de acesso',
      '/access-requests',
      Icons.mark_email_unread_outlined,
      permission: 'users',
    ),
  ]),
  NavGroup('Minha conta', Icons.person_outline, [
    NavDestination('Meu Perfil', '/profile', Icons.person_outline),
    NavDestination('Configurações', '/settings', Icons.tune_rounded),
    NavDestination('Ajuda', '/help', Icons.help_outline),
  ]),
];

final navigation = [for (final g in navigationGroups) ...g.children];
