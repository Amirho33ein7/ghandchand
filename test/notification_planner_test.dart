import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/medical_reference.dart';
import 'package:lowguard/notification_planner.dart';
import 'package:lowguard/meal_scheduler.dart';

void main() {
  test('medical hypoglycemia thresholds match centralized references', () {
    expect(MedicalReference.hypoLevel1, 70);
    expect(MedicalReference.hypoLevel2, 54);
    expect(MedicalReference.fastingDiabetesMin, 126);
  });

  test('recurring notification uses tomorrow after today time has passed', () {
    final entry = MealPlanEntry(
      time: DateTime(2026, 9, 23, 9, 30),
      title: 'صبحانه',
      note: '',
      mainMeal: true,
    );
    final next = NotificationPlanner.nextDailyOccurrence(
      DateTime(2026, 9, 23, 10),
      entry,
    );
    expect(next, DateTime(2026, 9, 24, 9, 30));
  });

  test('recurring meal notification ids are unique for meal slots', () {
    expect(NotificationPlanner.mealId(0), isNot(NotificationPlanner.mealId(1)));
    expect(NotificationPlanner.mealId(5), 210005);
  });
  test('daily occurrence stays today when the edited time is still ahead', () {
    final mealTime = DateTime(2026, 9, 24, 18, 30);
    final next = NotificationPlanner.nextDailyOccurrence(
      DateTime(2026, 9, 24, 10, 0),
      mealTime,
    );
    expect(next, DateTime(2026, 9, 24, 18, 30));
  });

  test('daily occurrence moves to tomorrow when the edited time has passed', () {
    final mealTime = DateTime(2026, 9, 24, 8, 30);
    final next = NotificationPlanner.nextDailyOccurrence(
      DateTime(2026, 9, 24, 10, 0),
      mealTime,
    );
    expect(next, DateTime(2026, 9, 25, 8, 30));
  });

  test('daily occurrence moves to tomorrow at the exact scheduled minute', () {
    final mealTime = DateTime(2026, 9, 24, 10, 0);
    final next = NotificationPlanner.nextDailyOccurrence(
      DateTime(2026, 9, 24, 10, 0),
      mealTime,
    );
    expect(next, DateTime(2026, 9, 25, 10, 0));
  });

  test('daily occurrence handles crossing midnight', () {
    final mealTime = DateTime(2026, 9, 24, 0, 30);
    final next = NotificationPlanner.nextDailyOccurrence(
      DateTime(2026, 9, 24, 23, 50),
      mealTime,
    );
    expect(next, DateTime(2026, 9, 25, 0, 30));
  });

  test('recurring notification ids are valid and unique for all six slots', () {
    final ids = List.generate(6, NotificationPlanner.mealId);
    expect(ids.toSet(), hasLength(6));
    expect(ids.first, 210000);
    expect(ids.last, 210005);
    expect(NotificationPlanner.isValidMealCount(0), isTrue);
    expect(NotificationPlanner.isValidMealCount(6), isTrue);
    expect(NotificationPlanner.isValidMealCount(7), isFalse);
  });

  test('invalid notification slot ids are rejected', () {
    expect(() => NotificationPlanner.mealId(-1), throwsArgumentError);
    expect(() => NotificationPlanner.mealId(6), throwsArgumentError);
  });

}
