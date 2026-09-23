import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/models.dart';
import 'package:lowguard.risk_engine.dart';

void main() {
  UserProfile baseProfile({bool history = false, bool night = false}) =>
      UserProfile(
        name: 'Test',
        sleepHour: 23,
        sleepMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        historyOfHypo: history,
        nighttimeHypo: night,
      );

  test('medical thresholds', () {
    expect(RiskEngine.glucoseBand(100), 'بالاتر از آستانه افت قند');
    expect(RiskEngine.glucoseBand(69), 'افت قند سطح ۱');
    expect(RiskEngine.glucoseBand(54), 'افت قند سطح ۱');
    expect(RiskEngine.glucoseBand(53.9), 'افت قند سطح ۲');
  });

  test('repeated historical lows create a risk window', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: baseProfile(history: true, night: true),
      readings: [
        GlucoseReading(
          time: DateTime(2026, 9, 22, 3),
          mgDl: 62,
          context: GlucoseContext.symptoms,
        ),
        GlucoseReading(
          time: DateTime(2026, 9, 23, 3, 10),
          mgDl: 58,
          context: GlucoseContext.bedtime,
        ),
      ],
      meals: const [],
      activities: const [],
      events: const [],
    );

    expect(windows, isNotEmpty);
    expect(windows.any((w) => w.start.hour == 3 || w.end.hour == 3), isTrue);
  });

  test('stale low older than 30 days is ignored', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: baseProfile(),
      readings: [
        GlucoseReading(
          time: DateTime(2026, 8, 1, 3),
          mgDl: 55,
          context: GlucoseContext.symptoms,
        ),
      ],
      meals: const [],
      activities: const [],
      events: const [],
    );

    expect(windows, isEmpty);
  });

  test('one normal reading alone creates no risk window', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: baseProfile(),
      readings: [
        GlucoseReading(
          time: DateTime(2026, 9, 23, 10),
          mgDl: 100,
          context: GlucoseContext.other,
        ),
      ],
      meals: const [],
      activities: const [],
      events: const [],
    );

    expect(windows, isEmpty);
  });

  test('long meal gap alone is not enough for an alert', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: baseProfile(),
      readings: const [],
      meals: [
        MealEntry(time: DateTime(2026, 9, 23, 8), kind: 'صبحانه'),
      ],
      activities: const [],
      events: const [],
    );

    expect(windows, isEmpty);
  });

  test('activity and history can create a check window', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: baseProfile(history: true),
      readings: const [],
      meals: [
        MealEntry(time: DateTime(2026, 9, 23, 8), kind: 'صبحانه'),
      ],
      activities: [
        ActivityEntry(
          time: DateTime(2026, 9, 23, 14),
          durationMinutes: 60,
          intensity: 'high',
        ),
      ],
      events: const [],
    );

    expect(windows, isNotEmpty);
  });

  test('level 3 event can exist without numeric glucose', () {
    final event = HypoglycemiaEvent(
      time: DateTime(2026, 9, 23, 3),
      symptoms: 'نیاز به کمک',
    );
    expect(event.measuredMgDl, isNull);
  });
}
