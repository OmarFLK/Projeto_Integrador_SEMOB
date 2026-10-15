import '../models/transport_models.dart';
import '../services/api_client.dart';
import 'transport_repository.dart';

class ApiTransportRepository implements TransportRepository {
  const ApiTransportRepository(this.client);

  final ApiClient client;

  @override
  Future<List<OperationDay>> getOperationDays({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('operation', period, OperationDay.fromJson, extra: query);

  @override
  Future<List<PassengerDay>> getPassengerDays({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('passengers', period, PassengerDay.fromJson, extra: query);

  @override
  Future<List<LineSummary>> getLines({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('lines', period, LineSummary.fromJson, extra: query);

  @override
  Future<List<TripRecord>> getTrips({
    String? period,
    Map<String, String> query = const {},
  }) => _getList(
    'trips',
    period,
    TripRecord.fromJson,
    extra: {...query, 'limit': 50},
  );

  @override
  Future<List<VehicleSummary>> getVehicles({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('vehicles', period, VehicleSummary.fromJson, extra: query);

  @override
  Future<List<FinancialDay>> getFinancialDays({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('financial', period, FinancialDay.fromJson, extra: query);

  @override
  Future<List<AnomalyRecord>> getAnomalies({
    String? period,
    Map<String, String> query = const {},
  }) => _getList('anomalies', period, AnomalyRecord.fromJson, extra: query);

  Future<List<T>> _getList<T>(
    String path,
    String? period,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic> extra = const {},
  }) async {
    final response = await client.dio.get<dynamic>(
      path,
      queryParameters: {'period': _periodCode(period), ...extra},
    );
    final List<dynamic> items = response.data is Map
        ? (response.data['items'] as List<dynamic>)
        : (response.data as List<dynamic>? ?? []);
    return items
        .map((item) => fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }
}

String _periodCode(String? label) {
  if (label != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(label)) return label;
  const periods = {
    'Julho de 2026': '2026-07',
    'Agosto de 2026': '2026-08',
    'Setembro de 2026': '2026-09',
  };
  return periods[label] ?? '2026-08';
}
