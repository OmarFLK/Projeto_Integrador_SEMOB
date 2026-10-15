import '../mocks/mock_operation_data.dart';
import '../mocks/mock_passenger_financial_data.dart';
import '../models/transport_models.dart';
import 'transport_repository.dart';

class MockTransportRepository implements TransportRepository {
  const MockTransportRepository();

  Future<List<T>> _mock<T>(List<T> data) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return data;
  }

  @override
  Future<List<AnomalyRecord>> getAnomalies({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(anomalyRecords);

  @override
  Future<List<FinancialDay>> getFinancialDays({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(financialDays);

  @override
  Future<List<LineSummary>> getLines({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(lineSummaries);

  @override
  Future<List<OperationDay>> getOperationDays({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(operationDays);

  @override
  Future<List<PassengerDay>> getPassengerDays({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(passengerDays);

  @override
  Future<List<TripRecord>> getTrips({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(tripRecords);

  @override
  Future<List<VehicleSummary>> getVehicles({
    String? period,
    Map<String, String> query = const {},
  }) => _mock(vehicleSummaries);
}
