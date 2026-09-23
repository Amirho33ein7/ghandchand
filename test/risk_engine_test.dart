import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/models.dart';
import 'package:lowguard/risk_engine.dart';

void main() {
  test('medical thresholds', () {
    expect(RiskEngine.glucoseBand(100), 'محدوده هدف عمومی');
    expect(RiskEngine.glucoseBand(69), 'افت قند سطح ۱');
    expect(RiskEngine.glucoseBand(54), 'افت قند سطح ۱');
    expect(RiskEngine.glucoseBand(53.9), 'افت قند سطح ۲');
  });

  test('repeated historical lows create a risk window', () {
    const p = UserProfile(
      name: 'Test',
      sleepHour: 23,
      sleepMinute: 0,
      wakeHour: 7,
      wakeMinute: 0,
      historyOfHypo: true,
      nighttimeHypo: true,
    );

    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: p,
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

  test('one normal reading alone creates no risk window', () {
    final windows = RiskEngine.calculateDay(
      day: DateTime(2026, 9, 23),
      profile: const UserProfile(
        name: 'Test',
        sleepHour: 23,
        sleepMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
      ),
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

  test('level 3 event may have no numeric glucose', () {
    const e = HypoglycemiaEvent(
      time: DateTime(2026, 9, 23, 3),
      symptoms: 'نیاز به کمک',
    );
    expect(e.measuredMgDl, isNull);
  });
}
