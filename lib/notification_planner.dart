import 'package:flutter/foundation.dart';

class NotificationPlanner {
  static const firstMealId = 210000;
  static const maxMealSlots = 6;

  static int mealId(int index) {
    if (index < 0 || index >= maxMealSlots) {
      throw ArgumentError.value(index, 'index', 'meal slot must be 0..5');
    }
    return firstMealId + index;
  }

  static DateTime nextDailyOccurrence(DateTime now, DateTime mealTime) {
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      mealTime.hour,
      mealTime.minute,
    );

    if (!candidate.isAfter(now)) {
      candidate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        mealTime.hour,
        mealTime.minute,
      );
    }

    return candidate;
  }

  static String debugPlan(DateTime now, List<DateTime> mealTimes) {
    final values = mealTimes
        .take(maxMealSlots)
        .map((meal) => nextDailyOccurrence(now, meal).toIso8601String())
        .join(',');
    return values;
  }

  static bool isValidMealCount(int count) => count >= 0 && count <= maxMealSlots;
}
