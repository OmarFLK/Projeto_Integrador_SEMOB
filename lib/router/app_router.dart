import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/ai_assistant/presentation/ai_assistant_page.dart';
import '../features/anomalies/presentation/anomalies_page.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/financial/presentation/financial_page.dart';
import '../features/fleet/presentation/fleet_page.dart';
import '../features/fleet/presentation/vehicle_detail_page.dart';
import '../features/help/presentation/help_page.dart';
import '../features/insights/presentation/insights_page.dart';
import '../features/lines/presentation/line_detail_page.dart';
import '../features/lines/presentation/lines_page.dart';
import '../features/operation/presentation/operation_page.dart';
import '../features/passengers/presentation/passengers_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/trips/presentation/trips_page.dart';
import '../features/users/presentation/profile_page.dart';
import '../features/users/presentation/users_page.dart';
import '../shared/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authenticated = ref.watch(
    authProvider.select((state) => state.isAuthenticated),
  );
  final user = ref.watch(authProvider.select((s) => s.user));
  final initializing = ref.watch(authProvider.select((s) => s.initializing));

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (initializing) return null;
      final atLogin = state.matchedLocation == '/login';
      if (!authenticated && !atLogin) return '/login';
      if (authenticated && atLogin) return '/dashboard';
      final permission = switch (state.uri.path) {
        '/users' => 'users',
        '/financial' => 'financial',
        '/reports' => 'export',
        '/assistant' => 'assistant',
        _ => 'read',
      };
      if (authenticated && user?.can(permission) != true) return '/dashboard';
      return null;
    },
    errorBuilder: (context, state) =>
        _NotFoundPage(message: state.error?.toString()),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          sessionExpired: state.uri.queryParameters['expired'] == 'true',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/operation', builder: (_, _) => const OperationPage()),
          GoRoute(path: '/trips', builder: (_, _) => const TripsPage()),
          GoRoute(
            path: '/passengers',
            builder: (_, _) => const PassengersPage(),
          ),
          GoRoute(
            path: '/lines',
            builder: (_, _) => const LinesPage(),
            routes: [
              GoRoute(
                path: ':code',
                builder: (_, state) =>
                    LineDetailPage(lineCode: state.pathParameters['code']!),
              ),
            ],
          ),
          GoRoute(
            path: '/fleet',
            builder: (_, _) => const FleetPage(),
            routes: [
              GoRoute(
                path: ':prefix',
                builder: (_, state) =>
                    VehicleDetailPage(prefix: state.pathParameters['prefix']!),
              ),
            ],
          ),
          GoRoute(path: '/financial', builder: (_, _) => const FinancialPage()),
          GoRoute(path: '/anomalies', builder: (_, _) => const AnomaliesPage()),
          GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
          GoRoute(
            path: '/assistant',
            builder: (_, _) => const AiAssistantPage(),
          ),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(path: '/users', builder: (_, _) => const UsersPage()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(path: '/help', builder: (_, _) => const HelpPage()),
        ],
      ),
    ],
  );
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.explore_off_outlined,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            const Text(
              'Página não encontrada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Ir para a Visão Geral'),
            ),
          ],
        ),
      ),
    ),
  );
}
