import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

const moduleViews = <String, List<(String, String)>>{
  '/dashboard': [
    ('overview', 'Resumo'),
    ('indicators', 'Indicadores'),
    ('lines', 'Por linha'),
  ],
  '/operation': [
    ('overview', 'Resumo'),
    ('trips', 'Viagens'),
    ('kilometres', 'Quilometragem'),
  ],
  '/passengers': [
    ('overview', 'Resumo'),
    ('composition', 'Composição'),
    ('evolution', 'Evolução'),
  ],
  '/financial': [('overview', 'Resumo'), ('movements', 'Movimentações')],
  '/reports': [('overview', 'Catálogo'), ('import', 'Importar dados')],
};
String activeModuleView(BuildContext context) {
  final state = GoRouterState.of(context);
  final views = moduleViews[state.uri.path];
  final value = state.uri.queryParameters['view'];
  return views?.any((v) => v.$1 == value) == true ? value! : 'overview';
}

class ModuleSection extends StatelessWidget {
  const ModuleSection({super.key, required this.views, required this.child});
  final Set<String> views;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      views.contains(activeModuleView(context))
      ? child
      : const SizedBox.shrink();
}

typedef DockDestination = ({String path, String label, IconData icon});

class ModuleTabs extends StatefulWidget {
  const ModuleTabs({super.key, this.destinations = const []});
  final List<DockDestination> destinations;
  @override
  State<ModuleTabs> createState() => _ModuleTabsState();
}

class _ModuleTabsState extends State<ModuleTabs> {
  final selectedKey = GlobalKey();
  String? lastLocation;
  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final views = moduleViews[uri.path];
    final items = views == null
        ? widget.destinations
        : <DockDestination>[
            for (final view in views)
              (
                path: uri
                    .replace(
                      queryParameters: {
                        ...uri.queryParameters,
                        'view': view.$1,
                      },
                    )
                    .toString(),
                label: view.$2,
                icon: switch (view.$1) {
                  'overview' => Icons.space_dashboard_outlined,
                  'composition' => Icons.donut_large_rounded,
                  'evolution' => Icons.show_chart_rounded,
                  'import' => Icons.file_upload_outlined,
                  'lines' => Icons.route_rounded,
                  'trips' => Icons.alt_route_rounded,
                  'kilometres' => Icons.timeline_rounded,
                  'movements' => Icons.receipt_long_outlined,
                  _ => Icons.bar_chart_rounded,
                },
              ),
          ];
    if (items.isEmpty) return const SizedBox.shrink();
    bool selected(DockDestination item) {
      final target = Uri.parse(item.path);
      if (views != null) {
        return target.queryParameters['view'] == activeModuleView(context);
      }
      if (target.path == '/settings' && uri.path == '/settings') {
        return target.queryParameters['tab'] ==
            (uri.queryParameters['tab'] ?? 'appearance');
      }
      return uri.path == target.path || uri.path.startsWith('${target.path}/');
    }

    if (lastLocation != uri.toString()) {
      lastLocation = uri.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final selectedContext = selectedKey.currentContext;
        if (mounted && selectedContext != null) {
          Scrollable.ensureVisible(selectedContext, alignment: .5);
        }
      });
    }
    return Semantics(
      label: 'Navegação contextual',
      container: true,
      child: Container(
        key: const Key('floating_context_dock'),
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.forest, AppColors.forestBlack, AppColors.olive],
          ),
          border: Border.all(color: AppColors.sage.withValues(alpha: .55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Builder(
                  builder: (context) {
                    final item = items[i];
                    final isSelected = selected(item);
                    return Padding(
                      key: isSelected ? selectedKey : null,
                      padding: EdgeInsets.only(
                        right: i == items.length - 1 ? 0 : 4,
                      ),
                      child: Semantics(
                        selected: isSelected,
                        button: true,
                        child: AnimatedContainer(
                          duration: DesignTokens.motion(
                            context,
                            DesignTokens.navigation,
                          ),
                          curve: DesignTokens.curve,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.ivory
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.lime.withValues(
                                        alpha: .13,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: views != null
                                  ? ValueKey('module_tab_${views[i].$1}')
                                  : ValueKey('dock_${item.path}'),
                              borderRadius: BorderRadius.circular(26),
                              onTap: isSelected
                                  ? null
                                  : () => context.go(item.path),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 13,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 17,
                                      color: isSelected
                                          ? AppColors.forestBlack
                                          : AppColors.softSage,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.forestBlack
                                            : AppColors.ivory,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
