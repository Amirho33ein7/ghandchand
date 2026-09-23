import 'meal_scheduler.dart';

class NotificationPlanner {
  static int mealId(int index) => 210000 + index;

  static DateTime nextDailyOccurrence(DateTime now, MealPlanEntry entry) {
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      entry.time.hour,
      entry.time.minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}