import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/medical_reference.dart';
import 'package:lowguard/notification_planner.dart';
import 'package:lowguard/meal_scheduler.dart';
import 'package:lowguard/models.dart';

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
}