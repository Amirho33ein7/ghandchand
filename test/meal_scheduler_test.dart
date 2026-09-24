import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/meal_scheduler.dart';
import 'package:lowguard/models.dart';

void main() {
  UserProfile profile({int meals = 3, bool history = false}) => UserProfile(
        name: 'Test',
        sleepHour: 23,
        sleepMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        mealsPerDay: meals,
        historyOfHypo: history,
      );

  test('builds a daily meal pattern inside waking hours', () {
    final result = MealScheduler.buildForDay(
      day: DateTime(2026, 9, 23),
      profile: profile(),
      readings: const [],
      events: const [],
    );

    expect(result.entries.length, 3);
    expect(result.entries.first.time, DateTime(2026, 9, 23, 7, 30));
    expect(result.entries.last.time.isBefore(DateTime(2026, 9, 23, 23)), isTrue);
  });

  test('adds one extra reminder on a long day when risk signals exist', () {
    final result = MealScheduler.buildForDay(
      day: DateTime(2026, 9, 23),
      profile: profile(meals: 3, history: true),
      readings: const [],
      events: const [],
    );

    expect(result.entries.length, 4);
  });

  test('does not diagnose from a non-fasting value alone', () {
    final result = MealScheduler.buildForDay(
      day: DateTime(2026, 9, 23),
      profile: UserProfile(
        name: 'Test',
        sleepHour: 23,
        sleepMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        nonFastingGlucose: 200,
      ),
      readings: const [],
      events: const [],
    );

    expect(result.note, contains('زمان آزمون مهم است'));
  });
  test('editing sleep and wake times changes the generated notification times', () {
    final early = MealScheduler.buildForDay(
      day: DateTime(2026, 9, 24),
      profile: UserProfile(
        name: 'Test',
        sleepHour: 23,
        sleepMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        mealsPerDay: 3,
      ),
      readings: const [],
      events: const [],
    );

    final edited = MealScheduler.buildForDay(
      day: DateTime(2026, 9, 24),
      profile: UserProfile(
        name: 'Test',
        sleepHour: 1,
        sleepMinute: 0,
        wakeHour: 9,
        wakeMinute: 0,
        mealsPerDay: 3,
      ),
      readings: const [],
      events: const [],
    );

    expect(early.entries.first.time, isNot(equals(edited.entries.first.time)));
    expect(early.entries.last.time, isNot(equals(edited.entries.last.time)));
    expect(edited.entries.first.time, DateTime(2026, 9, 24, 9, 30));
    expect(
      edited.entries.last.time.isBefore(DateTime(2026, 9, 25, 1, 0)),
      isTrue,
    );
  });

}
