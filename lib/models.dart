enum GlucoseContext { fasting, beforeMeal, afterMeal, bedtime, symptoms, other }

extension GlucoseContextLabel on GlucoseContext {
  String get label => switch (this) {
        GlucoseContext.fasting => 'ناشتا',
        GlucoseContext.beforeMeal => 'قبل غذا',
        GlucoseContext.afterMeal => 'بعد غذا',
        GlucoseContext.bedtime => 'قبل خواب',
        GlucoseContext.symptoms => 'هنگام علائم',
        GlucoseContext.other => 'سایر',
      };
}

enum RiskLevel { low, medium, high, veryHigh }

extension RiskLevelLabel on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'پایین',
        RiskLevel.medium => 'متوسط',
        RiskLevel.high => 'بالا',
        RiskLevel.veryHigh => 'بسیار بالا',
      };
}

class UserProfile {
  final int id;
  final String name;
  final double? fastingGlucose;
  final double? nonFastingGlucose;
  final int sleepHour;
  final int sleepMinute;
  final int wakeHour;
  final int wakeMinute;
  final String glucoseUnit;
  final String? diabetesType;
  final bool historyOfHypo;
  final bool nighttimeHypo;
  final bool usesInsulin;
  final bool usesGlucoseLoweringMedication;
  final int mealsPerDay;

  const UserProfile({
    this.id = 1,
    required this.name,
    this.fastingGlucose,
    this.nonFastingGlucose,
    required this.sleepHour,
    required this.sleepMinute,
    required this.wakeHour,
    required this.wakeMinute,
    this.glucoseUnit = 'mg/dL',
    this.diabetesType,
    this.historyOfHypo = false,
    this.nighttimeHypo = false,
    this.usesInsulin = false,
    this.usesGlucoseLoweringMedication = false,
    this.mealsPerDay = 3,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'fasting_glucose': fastingGlucose,
        'non_fasting_glucose': nonFastingGlucose,
        'sleep_hour': sleepHour,
        'sleep_minute': sleepMinute,
        'wake_hour': wakeHour,
        'wake_minute': wakeMinute,
        'glucose_unit': glucoseUnit,
        'diabetes_type': diabetesType,
        'history_of_hypo': historyOfHypo ? 1 : 0,
        'nighttime_hypo': nighttimeHypo ? 1 : 0,
        'uses_insulin': usesInsulin ? 1 : 0,
        'uses_glucose_lowering_medication':
            usesGlucoseLoweringMedication ? 1 : 0,
        'meals_per_day': mealsPerDay,
      };

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        id: (m['id'] as int?) ?? 1,
        name: (m['name'] as String?) ?? '',
        fastingGlucose: (m['fasting_glucose'] as num?)?.toDouble(),
        nonFastingGlucose: (m['non_fasting_glucose'] as num?)?.toDouble(),
        sleepHour: (m['sleep_hour'] as int?) ?? 23,
        sleepMinute: (m['sleep_minute'] as int?) ?? 0,
        wakeHour: (m['wake_hour'] as int?) ?? 7,
        wakeMinute: (m['wake_minute'] as int?) ?? 0,
        glucoseUnit: (m['glucose_unit'] as String?) ?? 'mg/dL',
        diabetesType: m['diabetes_type'] as String?,
        historyOfHypo: (m['history_of_hypo'] as int? ?? 0) == 1,
        nighttimeHypo: (m['nighttime_hypo'] as int? ?? 0) == 1,
        usesInsulin: (m['uses_insulin'] as int? ?? 0) == 1,
        usesGlucoseLoweringMedication:
            (m['uses_glucose_lowering_medication'] as int? ?? 0) == 1,
        mealsPerDay: (m['meals_per_day'] as int?) ?? 3,
      );
}

class GlucoseReading {
  final int? id;
  final DateTime time;
  final double mgDl;
  final GlucoseContext context;

  const GlucoseReading({
    this.id,
    required this.time,
    required this.mgDl,
    required this.context,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'time': time.toIso8601String(),
        'mg_dl': mgDl,
        'context': context.name,
      };

  factory GlucoseReading.fromMap(Map<String, Object?> m) => GlucoseReading(
        id: m['id'] as int?,
        time: DateTime.parse(m['time'] as String),
        mgDl: (m['mg_dl'] as num).toDouble(),
        context: GlucoseContext.values.firstWhere(
          (e) => e.name == m['context'],
          orElse: () => GlucoseContext.other,
        ),
      );
}

class MealEntry {
  final int? id;
  final DateTime time;
  final String kind;

  const MealEntry({this.id, required this.time, required this.kind});

  Map<String, Object?> toMap() => {
        'id': id,
        'time': time.toIso8601String(),
        'kind': kind,
      };

  factory MealEntry.fromMap(Map<String, Object?> m) => MealEntry(
        id: m['id'] as int?,
        time: DateTime.parse(m['time'] as String),
        kind: (m['kind'] as String?) ?? 'وعده',
      );
}

class ActivityEntry {
  final int? id;
  final DateTime time;
  final int durationMinutes;
  final String intensity;

  const ActivityEntry({
    this.id,
    required this.time,
    required this.durationMinutes,
    required this.intensity,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'time': time.toIso8601String(),
        'duration_minutes': durationMinutes,
        'intensity': intensity,
      };

  factory ActivityEntry.fromMap(Map<String, Object?> m) => ActivityEntry(
        id: m['id'] as int?,
        time: DateTime.parse(m['time'] as String),
        durationMinutes: (m['duration_minutes'] as int?) ?? 0,
        intensity: (m['intensity'] as String?) ?? 'medium',
      );
}

class HypoglycemiaEvent {
  final int? id;
  final DateTime time;
  final double? measuredMgDl;
  final String? symptoms;

  const HypoglycemiaEvent({
    this.id,
    required this.time,
    this.measuredMgDl,
    this.symptoms,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'time': time.toIso8601String(),
        'measured_mg_dl': measuredMgDl,
        'symptoms': symptoms,
      };

  factory HypoglycemiaEvent.fromMap(Map<String, Object?> m) =>
      HypoglycemiaEvent(
        id: m['id'] as int?,
        time: DateTime.parse(m['time'] as String),
        measuredMgDl: (m['measured_mg_dl'] as num?)?.toDouble(),
        symptoms: m['symptoms'] as String?,
      );
}

class RiskWindow {
  final DateTime start;
  final DateTime end;
  final int score;
  final RiskLevel level;
  final double confidence;
  final String reason;

  const RiskWindow({
    required this.start,
    required this.end,
    required this.score,
    required this.level,
    required this.confidence,
    required this.reason,
  });
}
