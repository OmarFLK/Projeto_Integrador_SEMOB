enum TripStatus { completed, notCompleted, notStarted, notFinished }

extension TripStatusLabel on TripStatus {
  String get label => switch (this) {
    TripStatus.completed => 'Realizada',
    TripStatus.notCompleted => 'Não realizada',
    TripStatus.notStarted => 'Não iniciada',
    TripStatus.notFinished => 'Não terminada',
  };
}

class OperationDay {
  const OperationDay({
    required this.day,
    required this.weekday,
    required this.vehicles,
    required this.maxVehiclesInRange,
    required this.scheduledTrips,
    required this.completedTrips,
    required this.productiveKm,
    required this.unproductiveKm,
  });

  final int day;
  final String weekday;
  final int vehicles;
  final int maxVehiclesInRange;
  final int scheduledTrips;
  final int completedTrips;
  final double productiveKm;
  final double unproductiveKm;

  int get tripDifference => scheduledTrips - completedTrips;
  double get totalKm => productiveKm + unproductiveKm;
}

class PassengerDay {
  const PassengerDay({
    required this.day,
    required this.turnstile,
    required this.advance,
    required this.nonPaying,
  });

  final int day;
  final int turnstile;
  final int advance;
  final int nonPaying;

  int get paying => turnstile + advance;
  int get total => paying + nonPaying;
}

class LineSummary {
  const LineSummary({
    required this.code,
    required this.trips,
    required this.totalKm,
    required this.performance,
  });

  final String code;
  final int trips;
  final double totalKm;
  final double performance;
}

class TripRecord {
  const TripRecord({
    required this.date,
    required this.line,
    required this.vehicle,
    required this.activity,
    required this.direction,
    required this.timeRange,
    required this.start,
    required this.end,
    required this.productiveKm,
    required this.unproductiveKm,
    required this.status,
  });

  final String date;
  final String line;
  final String vehicle;
  final String activity;
  final String direction;
  final String timeRange;
  final String start;
  final String end;
  final double productiveKm;
  final double unproductiveKm;
  final TripStatus status;

  double get totalKm => productiveKm + unproductiveKm;
}

class VehicleSummary {
  const VehicleSummary({
    required this.prefix,
    required this.lines,
    required this.trips,
    required this.totalKm,
    required this.firstRecord,
    required this.lastRecord,
    required this.status,
  });

  final String prefix;
  final List<String> lines;
  final int trips;
  final double totalKm;
  final String firstRecord;
  final String lastRecord;
  final String status;
}

class FinancialDay {
  const FinancialDay({
    required this.day,
    required this.transferredCredits,
    required this.finalBalance,
  });

  final int day;
  final double transferredCredits;
  final double finalBalance;
}

enum AnomalyLevel { critical, attention, information }

class AnomalyRecord {
  const AnomalyRecord({
    required this.level,
    required this.date,
    required this.line,
    required this.description,
    required this.metric,
    this.vehicle,
  });

  final AnomalyLevel level;
  final String date;
  final String line;
  final String? vehicle;
  final String description;
  final String metric;
}

class GlobalFilters {
  const GlobalFilters({
    this.period = 'Agosto de 2026',
    this.line = 'Todas as linhas',
    this.vehicle = 'Todos os veículos',
    this.direction = 'Todos os sentidos',
    this.timeRange = 'Todas as faixas',
  });

  final String period;
  final String line;
  final String vehicle;
  final String direction;
  final String timeRange;

  GlobalFilters copyWith({
    String? period,
    String? line,
    String? vehicle,
    String? direction,
    String? timeRange,
  }) {
    return GlobalFilters(
      period: period ?? this.period,
      line: line ?? this.line,
      vehicle: vehicle ?? this.vehicle,
      direction: direction ?? this.direction,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}
