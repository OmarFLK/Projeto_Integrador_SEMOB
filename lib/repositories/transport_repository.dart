import '../models/transport_models.dart';

abstract interface class TransportRepository {
  Future<List<OperationDay>> getOperationDays();
  Future<List<PassengerDay>> getPassengerDays();
  Future<List<LineSummary>> getLines();
  Future<List<TripRecord>> getTrips();
  Future<List<VehicleSummary>> getVehicles();
  Future<List<FinancialDay>> getFinancialDays();
  Future<List<AnomalyRecord>> getAnomalies();
}
