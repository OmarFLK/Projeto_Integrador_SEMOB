import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/transport_models.dart';
import '../../services/api_client.dart' show apiError;
import '../providers/app_providers.dart';
import 'forest_widgets.dart';
import 'viewport_entrance.dart';
import 'equal_height_grid.dart';
export 'equal_height_grid.dart';
import 'analytics_charts.dart';
import 'global_filter_bar.dart';
export 'forest_widgets.dart';
export 'module_tabs.dart';

class PageBody extends ConsumerWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = 1600,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = AppBreakpoints.isMobile(context);
    final compact = ref.watch(preferencesProvider).value?['compact'] == true;
    return KeyedSubtree(
      key: ValueKey(
        '${GoRouterState.of(context).uri.path}:${GoRouterState.of(context).uri.queryParameters}',
      ),
      child: SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          compact
              ? AppSpacing.sm
              : mobile
              ? AppSpacing.md
              : AppSpacing.lg,
          compact
              ? AppSpacing.sm
              : mobile
              ? AppSpacing.md
              : AppSpacing.lg,
          compact
              ? AppSpacing.sm
              : mobile
              ? AppSpacing.md
              : AppSpacing.lg,
          112,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const SizedBox(height: 24),
                Text(
                  'SEMOB  /  São Caetano do Sul',
                  style: TextStyle(
                    color: context.palette.muted,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                if (const String.fromEnvironment(
                  'SEMOB_PRODUCT_CREDIT',
                ).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    const String.fromEnvironment('SEMOB_PRODUCT_CREDIT'),
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
        ),
      ],
    );
    final path = GoRouterState.of(context).uri.path;
    return LayoutBuilder(
      builder: (context, constraints) {
        final periodOnly =
            action is GlobalFilterBar &&
            !path.startsWith('/lines') &&
            !['/trips', '/fleet', '/anomalies'].contains(path);
        if (action != null &&
            constraints.maxWidth >= 900 &&
            (periodOnly || action is! GlobalFilterBar)) {
          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: periodOnly ? 280 : constraints.maxWidth * .45,
                ),
                child: action!,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleBlock,
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.change,
    this.positive = true,
    this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? change;
  final bool positive;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return SemobGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.palette.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: context.palette.green, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: change == null
                      ? const SizedBox.shrink()
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: positive
                                  ? context.palette.greenLight
                                  : context.palette.redSoft,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              change!,
                              style: TextStyle(
                                color: positive
                                    ? context.palette.greenDark
                                    : context.palette.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SemobAnimatedCounter(
              value: value,
              style:
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.ink,
                  ) ??
                  const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.muted, fontSize: 13),
          ),
          ...[
            const SizedBox(height: 6),
            Text(
              helper ?? '',
              style: TextStyle(color: context.palette.muted, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 340
            ? 1
            : width < 760
            ? 2
            : width < 1000
            ? (children.length % 3 == 0 ? 3 : 2)
            : 4;
        return EqualHeightGrid(
          columns: columns,
          children: [
            for (final entry in children.indexed)
              ViewportEntrance(order: entry.$1, child: entry.$2),
          ],
        );
      },
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SemobGlassCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null &&
                  (child is AnalyticsLineChart ||
                      child is AnalyticsBarChart ||
                      child is DistributionDonut ||
                      child is AnalyticsStackedBarChart))
                IconButton(
                  tooltip: 'Ampliar gráfico',
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialog) => Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fechar gráfico',
                                      onPressed: () => Navigator.pop(dialog),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle!,
                                    style: TextStyle(
                                      color: context.palette.muted,
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                child,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class TwoColumnLayout extends StatelessWidget {
  const TwoColumnLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return EqualHeightGrid(
          weights: [leftFlex, rightFlex],
          children: [left, right],
        );
      },
    );
  }
}

class DataSourceNote extends StatelessWidget {
  const DataSourceNote({
    super.key,
    this.text =
        'Fonte: relatórios SmartData fornecidos pela SEMOB • período selecionado',
    this.provisional = false,
  });

  final String text;
  final bool provisional;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: provisional
            ? context.palette.amberSoft
            : context.palette.blueSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            provisional ? Icons.info_outline : Icons.storage_outlined,
            color: provisional ? context.palette.amber : context.palette.blue,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.palette.ink, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.kind = StatusKind.good,
  });

  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (kind) {
      StatusKind.good => (
        context.palette.greenLight,
        context.palette.greenDark,
      ),
      StatusKind.warning => (context.palette.amberSoft, context.palette.amber),
      StatusKind.danger => (context.palette.redSoft, context.palette.red),
      StatusKind.neutral => (context.palette.canvas, context.palette.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum StatusKind { good, warning, danger, neutral }

StatusKind tripStatusKind(TripStatus status) => switch (status) {
  TripStatus.completed => StatusKind.good,
  TripStatus.notCompleted => StatusKind.danger,
  TripStatus.notStarted || TripStatus.notFinished => StatusKind.warning,
};

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage = 'Nenhum registro encontrado.',
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T>) builder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const SemobLoadingSkeleton(),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: context.palette.red,
                size: 32,
              ),
              const SizedBox(height: 10),
              const Text('Não foi possível carregar os dados.'),
              const SizedBox(height: 4),
              Text(
                apiError(error),
                style: TextStyle(color: context.palette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      data: (data) =>
          data.isEmpty ? SemobEmptyState(message: emptyMessage) : builder(data),
    );
  }
}
