import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../models/transport_models.dart';
import '../../repositories/api_transport_repository.dart';
import '../../repositories/transport_repository.dart';
import '../../services/api_client.dart';
export '../../services/api_client.dart' show apiClientProvider;

final transportRepositoryProvider = Provider<TransportRepository>(
  (ref) => ApiTransportRepository(ref.watch(apiClientProvider)),
);

class FiltersController extends Notifier<GlobalFilters> {
  @override
  GlobalFilters build() => const GlobalFilters();
  void update(GlobalFilters filters) => state = filters;
  void reset() => state = GlobalFilters(period: state.period);
}

final globalFiltersProvider =
    NotifierProvider<FiltersController, GlobalFilters>(FiltersController.new);
final operationProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getOperationDays(period: f.period, query: f.query(dimensions: false));
});
final passengersProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getPassengerDays(period: f.period, query: f.query(dimensions: false));
});
final linesProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getLines(
        period: f.period,
        query: {
          'period': f.period,
          if (f.line != 'Todas as linhas')
            'line': f.line.replaceFirst('Linha ', ''),
        },
      );
});
final tripsProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getTrips(period: f.period, query: f.query());
});
final vehiclesProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getVehicles(period: f.period, query: f.query());
});
final financialProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getFinancialDays(period: f.period, query: f.query(dimensions: false));
});
final anomaliesProvider = FutureProvider((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final f = ref.watch(globalFiltersProvider);
  return ref
      .watch(transportRepositoryProvider)
      .getAnomalies(
        period: f.period,
        query: {
          'period': f.period,
          if (f.line != 'Todas as linhas')
            'line': f.line.replaceFirst('Linha ', ''),
        },
      );
});
final remoteProvider = FutureProvider.autoDispose.family<dynamic, String>((
  ref,
  path,
) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  return (await ref.watch(apiClientProvider).dio.get<dynamic>(path)).data;
});
final tripPageProvider = FutureProvider.autoDispose.family<TripPage, String>((
  ref,
  query,
) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get<Map<String, dynamic>>(
        'trips',
        queryParameters: Uri.splitQueryString(query),
      );
  return TripPage.fromJson(response.data!);
});
final optionsProvider = FutureProvider((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final period = ref.watch(globalFiltersProvider.select((f) => f.period));
  return (await ref
          .watch(apiClientProvider)
          .dio
          .get<Map<String, dynamic>>(
            'options',
            queryParameters: {'period': period},
          ))
      .data!;
});

class PreferencesController extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    ref.watch(authProvider.select((s) => s.user?.id));
    return (await ref
            .watch(apiClientProvider)
            .dio
            .get<Map<String, dynamic>>('preferences'))
        .data!;
  }

  Future<void> save(Map<String, dynamic> patch) async {
    final before = state.value ?? <String, dynamic>{};
    state = AsyncData({...before, ...patch});
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .put<Map<String, dynamic>>('preferences', data: patch);
      if (ref.mounted) state = AsyncData(response.data!);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, Map<String, dynamic>>(
      PreferencesController.new,
    );
void refreshData(WidgetRef ref) {
  ref.invalidate(operationProvider);
  ref.invalidate(passengersProvider);
  ref.invalidate(linesProvider);
  ref.invalidate(tripsProvider);
  ref.invalidate(vehiclesProvider);
  ref.invalidate(financialProvider);
  ref.invalidate(anomaliesProvider);
  ref.invalidate(optionsProvider);
  ref.invalidate(remoteProvider);
  ref.invalidate(tripPageProvider);
}
