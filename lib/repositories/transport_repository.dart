import '../models/transport_models.dart';

abstract interface class TransportRepository {
  Future<List<OperationDay>> getOperationDays({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<PassengerDay>> getPassengerDays({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<LineSummary>> getLines({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<TripRecord>> getTrips({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<VehicleSummary>> getVehicles({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<FinancialDay>> getFinancialDays({
    String? period,
    Map<String, String> query = const {},
  });
  Future<List<AnomalyRecord>> getAnomalies({
    String? period,
    Map<String, String> query = const {},
  });
}
