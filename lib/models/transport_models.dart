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
    this.date = '',
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
  final String date;
  final String weekday;
  final int vehicles;
  final int maxVehiclesInRange;
  final int scheduledTrips;
  final int completedTrips;
  final double productiveKm;
  final double unproductiveKm;

  factory OperationDay.fromJson(Map<String, dynamic> json) => OperationDay(
    date: json['date'] as String? ?? '',
    day: json['day'] as int,
    weekday: json['weekday'] as String,
    vehicles: json['vehicles'] as int,
    maxVehiclesInRange: json['maxVehiclesInRange'] as int,
    scheduledTrips: json['scheduledTrips'] as int,
    completedTrips: json['completedTrips'] as int,
    productiveKm: (json['productiveKm'] as num).toDouble(),
    unproductiveKm: (json['unproductiveKm'] as num).toDouble(),
  );

  int get tripDifference => scheduledTrips - completedTrips;
  double get totalKm => productiveKm + unproductiveKm;
}

class PassengerDay {
  const PassengerDay({
    this.date = '',
    required this.day,
    required this.turnstile,
    required this.advance,
    required this.nonPaying,
  });

  final int day;
  final String date;
  final int turnstile;
  final int advance;
  final int nonPaying;

  factory PassengerDay.fromJson(Map<String, dynamic> json) => PassengerDay(
    date: json['date'] as String? ?? '',
    day: json['day'] as int,
    turnstile: json['turnstile'] as int,
    advance: json['advance'] as int,
    nonPaying: json['nonPaying'] as int,
  );

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

  factory LineSummary.fromJson(Map<String, dynamic> json) => LineSummary(
    code: json['code'] as String,
    trips: (json['trips'] as num).round(),
    totalKm: (json['totalKm'] as num).toDouble(),
    performance: (json['performance'] as num).toDouble(),
  );
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

  factory TripRecord.fromJson(Map<String, dynamic> json) => TripRecord(
    date: json['date'] as String,
    line: json['line'] as String,
    vehicle: json['vehicle'] as String,
    activity: json['activity'] as String,
    direction: json['direction'] as String,
    timeRange: json['timeRange'] as String,
    start: json['start'] as String,
    end: json['end'] as String,
    productiveKm: (json['productiveKm'] as num).toDouble(),
    unproductiveKm: (json['unproductiveKm'] as num).toDouble(),
    status: TripStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => TripStatus.completed,
    ),
  );

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

  factory VehicleSummary.fromJson(Map<String, dynamic> json) => VehicleSummary(
    prefix: json['prefix'] as String,
    lines: (json['lines'] as List).cast<String>(),
    trips: (json['trips'] as num).round(),
    totalKm: (json['totalKm'] as num).toDouble(),
    firstRecord: json['firstRecord'] as String,
    lastRecord: json['lastRecord'] as String,
    status: json['status'] as String,
  );
}

class FinancialDay {
  const FinancialDay({
    this.date = '',
    this.incomplete = false,
    required this.day,
    required this.transferredCredits,
    required this.finalBalance,
  });

  final int day;
  final String date;
  final bool incomplete;
  final double transferredCredits;
  final double finalBalance;

  factory FinancialDay.fromJson(Map<String, dynamic> json) => FinancialDay(
    date: json['date'] as String? ?? '',
    incomplete: json['incomplete'] == true,
    day: json['day'] as int,
    transferredCredits: (json['transferredCredits'] as num).toDouble(),
    finalBalance: (json['finalBalance'] as num).toDouble(),
  );
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

  factory AnomalyRecord.fromJson(Map<String, dynamic> json) => AnomalyRecord(
    level: AnomalyLevel.values.firstWhere(
      (level) => level.name == json['level'],
      orElse: () => AnomalyLevel.information,
    ),
    date: json['date'] as String,
    line: json['line'] as String,
    vehicle: json['vehicle'] as String?,
    description: json['description'] as String,
    metric: json['metric'] as String,
  );
}

class GlobalFilters {
  const GlobalFilters({
    this.period = '2026-08',
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

  Map<String, String> query({bool dimensions = true}) => {
    'period': period,
    if (dimensions && line != 'Todas as linhas')
      'line': line.replaceFirst('Linha ', ''),
    if (dimensions && vehicle != 'Todos os veículos') 'vehicle': vehicle,
    if (dimensions && direction != 'Todos os sentidos') 'direction': direction,
    if (dimensions && timeRange != 'Todas as faixas') 'timeRange': timeRange,
  };
}

class TripPage {
  const TripPage(this.items, this.total, this.offset, this.limit);
  final List<TripRecord> items;
  final int total, offset, limit;
  factory TripPage.fromJson(Map<String, dynamic> json) => TripPage(
    (json['items'] as List)
        .map((r) => TripRecord.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(),
    json['total'] as int,
    json['offset'] as int,
    json['limit'] as int,
  );
}
