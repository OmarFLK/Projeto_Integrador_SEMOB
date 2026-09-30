import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transport_models.dart';
import '../../repositories/mock_transport_repository.dart';
import '../../repositories/transport_repository.dart';
import '../../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final transportRepositoryProvider = Provider<TransportRepository>(
  (ref) => const MockTransportRepository(),
);

final operationProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getOperationDays(),
);
final passengersProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getPassengerDays(),
);
final linesProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getLines(),
);
final tripsProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getTrips(),
);
final vehiclesProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getVehicles(),
);
final financialProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getFinancialDays(),
);
final anomaliesProvider = FutureProvider(
  (ref) => ref.watch(transportRepositoryProvider).getAnomalies(),
);

class FiltersController extends Notifier<GlobalFilters> {
  @override
  GlobalFilters build() => const GlobalFilters();

  void update(GlobalFilters filters) => state = filters;
  void reset() => state = const GlobalFilters();
}

final globalFiltersProvider =
    NotifierProvider<FiltersController, GlobalFilters>(FiltersController.new);
