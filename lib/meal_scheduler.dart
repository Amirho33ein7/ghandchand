import 'models.dart';

class MealPlanEntry {
  final DateTime time;
  final String title;
  final String note;
  final bool mainMeal;

  const MealPlanEntry({
    required this.time,
    required this.title,
    required this.note,
    required this.mainMeal,
  });
}

class MealScheduleResult {
  final List<MealPlanEntry> entries;
  final String note;

  const MealScheduleResult({
    required this.entries,
    required this.note,
  });
}

class MealScheduler {
  static MealScheduleResult buildForDay({
    required DateTime day,
    required UserProfile profile,
    required List<GlucoseReading> readings,
    required List<HypoglycemiaEvent> events,
  }) {
    final wake = DateTime(
      day.year,
      day.month,
      day.day,
      profile.wakeHour,
      profile.wakeMinute,
    );
    var sleep = DateTime(
      day.year,
      day.month,
      day.day,
      profile.sleepHour,
      profile.sleepMinute,
    );
    if (!sleep.isAfter(wake)) {
      sleep = sleep.add(const Duration(days: 1));
    }

    final recentCutoff = day.subtract(const Duration(days: 30));
    final hasRecentLow = readings.any(
          (r) => r.time.isAfter(recentCutoff) && r.mgDl < RiskThresholds.level1,
        ) ||
        events.any((e) => e.time.isAfter(recentCutoff));

    final lowBaseline = (profile.fastingGlucose ?? double.infinity) < 80 ||
        (profile.nonFastingGlucose ?? double.infinity) < 80;

    final cautious = profile.historyOfHypo ||
        profile.nighttimeHypo ||
        profile.usesInsulin ||
        profile.usesGlucoseLoweringMedication ||
        hasRecentLow ||
        lowBaseline;

    var count = profile.mealsPerDay.clamp(1, 6);
    final awakeMinutes = sleep.difference(wake).inMinutes;

    if (cautious && count < 4 && awakeMinutes >= 12 * 60) {
      count = 4;
    }

    final start = wake.add(const Duration(minutes: 30));
    final end = sleep.subtract(const Duration(hours: 3));
    final span = end.difference(start).inMinutes;

    final entries = <MealPlanEntry>[];
    if (span <= 0) {
      entries.add(
        MealPlanEntry(
          time: start,
          title: 'وعده امروز',
          mainMeal: true,
          note: 'زمان یادآوری است؛ مقدار و نوع غذا را طبق برنامه درمانی یا عادت معمول خود تعیین کنید.',
        ),
      );
    } else if (count == 1) {
      entries.add(
        MealPlanEntry(
          time: start,
          title: 'وعده اصلی',
          mainMeal: true,
          note: 'زمان یادآوری است؛ این اعلان مقدار غذا یا درمان را تعیین نمی‌کند.',
        ),
      );
    } else {
      final step = (span / (count - 1)).round();
      for (var i = 0; i < count; i++) {
        final time = start.add(Duration(minutes: step * i));
        final title = switch (i) {
          0 => 'صبحانه',
          1 when count == 2 => 'وعده دوم',
          1 => 'میان‌وعده',
          2 when count == 3 => 'ناهار',
          2 => 'ناهار',
          3 when count == 4 => 'شام',
          3 => 'میان‌وعده',
          4 when count == 5 => 'شام',
          4 => 'وعده پنجم',
          _ => 'وعده ششم',
        };

        final mainMeal = switch (title) {
          'صبحانه' || 'ناهار' || 'شام' => true,
          _ => false,
        };

        entries.add(
          MealPlanEntry(
            time: time,
            title: title,
            mainMeal: mainMeal,
            note: cautious
                ? 'یادآوری برای منظم‌تر ماندن فاصله وعده‌ها؛ افت قند را تضمین نمی‌کند. در صورت قند پایین، طبق برنامه درمانی خود اقدام کنید.'
                : 'یادآوری برای حفظ الگوی منظم روزانه؛ این زمان به‌تنهایی تضمین‌کننده کنترل قند نیست.',
          ),
        );
      }
    }

    final warnings = <String>[];
    final fasting = profile.fastingGlucose;
    final nonFasting = profile.nonFastingGlucose;

    if (fasting != null && fasting < RiskThresholds.level1) {
      warnings.add('قند ناشتا زیر 70 ثبت شده؛ زمان‌بندی وعده جای درمان افت قند نیست.');
    }
    if (nonFasting != null && nonFasting < RiskThresholds.level1) {
      warnings.add('قند غیرناشتا زیر 70 ثبت شده؛ برای افت قند طبق برنامه درمانی اقدام کنید.');
    }
    if (fasting != null && fasting >= 126) {
      warnings.add('قند ناشتا 126 یا بالاتر ثبت شده؛ این عدد برای تشخیص باید در چارچوب آزمایش و ارزیابی پزشکی تفسیر شود.');
    }
    if (nonFasting != null && nonFasting >= 200) {
      warnings.add('قند غیرناشتا 200 یا بالاتر ثبت شده؛ زمان آزمون مهم است و این عدد را اپ به‌تنهایی تشخیص نمی‌دهد.');
    }

    return MealScheduleResult(
      entries: entries,
      note: warnings.isEmpty
          ? 'زمان‌ها بر پایه ساعت خواب/بیداری، تعداد وعده‌های انتخابی و شاخص‌های خطر ثبت‌شده محاسبه شده‌اند.'
          : warnings.join(' '),
    );
  }

  static List<MealPlanEntry> buildDays({
    required DateTime firstDay,
    required UserProfile profile,
    required List<GlucoseReading> readings,
    required List<HypoglycemiaEvent> events,
    int days = 3,
  }) {
    final output = <MealPlanEntry>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(firstDay.year, firstDay.month, firstDay.day + i);
      output.addAll(
        buildForDay(
          day: day,
          profile: profile,
          readings: readings,
          events: events,
        ).entries,
      );
    }
    return output;
  }
}

class RiskThresholds {
  static const double level1 = 70;
  static const double level2 = 54;
}
