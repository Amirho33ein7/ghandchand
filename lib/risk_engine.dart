import 'dart:math' as math;
import 'models.dart';
import 'medical_reference.dart';

class RiskEngine {
  static const level1 = MedicalReference.hypoLevel1;
  static const level2 = MedicalReference.hypoLevel2;

  static RiskLevel classify(num score) => score >= 80
      ? RiskLevel.veryHigh
      : score >= 60
          ? RiskLevel.high
          : score >= 30
              ? RiskLevel.medium
              : RiskLevel.low;

  static String glucoseBand(double mgDl) {
    if (mgDl < level2) return 'افت قند سطح ۲';
    if (mgDl < level1) return 'افت قند سطح ۱';
    return 'بالاتر از آستانه افت قند';
  }

  static double _clockDistance(int a, int b) {
    final d = (a - b).abs();
    return math.min(d, 1440 - d).toDouble();
  }

  static bool _sleeping(int minute, UserProfile p) {
    final s = p.sleepHour * 60 + p.sleepMinute;
    final w = p.wakeHour * 60 + p.wakeMinute;
    if (s == w) return true;
    if (s < w) return minute >= s && minute < w;
    return minute >= s || minute < w;
  }

  static double _ageWeight(DateTime target, DateTime observed) {
    final hours = target.difference(observed).inHours;
    if (hours < 0) return 0;
    final days = hours / 24.0;
    if (days > 30) return 0;
    if (days <= 7) return 1.0;
    if (days <= 14) return 0.75;
    return 0.5;
  }

  static DateTime? _latestMealBefore(
    DateTime target,
    List<MealEntry> meals,
  ) {
    final candidates = meals.where((m) {
      final diff = target.difference(m.time);
      return !diff.isNegative && diff <= const Duration(hours: 24);
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.time.compareTo(a.time));
    return candidates.first.time;
  }

  static List<RiskWindow> calculateDay({
    required DateTime day,
    required UserProfile profile,
    required List<GlucoseReading> readings,
    required List<MealEntry> meals,
    required List<ActivityEntry> activities,
    required List<HypoglycemiaEvent> events,
  }) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final raw = <RiskWindow>[];

    for (var i = 0; i < 48; i++) {
      final start = startOfDay.add(Duration(minutes: i * 30));
      final minute = start.hour * 60 + start.minute;
      var score = 0;
      var evidence = 0;
      final reasons = <String>[];

      for (final r in readings) {
        final weight = _ageWeight(start, r.time);
        if (weight == 0 ||
            _clockDistance(minute, r.time.hour * 60 + r.time.minute) > 60) {
          continue;
        }

        if (r.mgDl < level2) {
          score += (45 * weight).round();
          reasons.add('سابقه قند کمتر از 54');
          evidence += 2;
        } else if (r.mgDl < level1) {
          score += (30 * weight).round();
          reasons.add('سابقه قند کمتر از 70');
          evidence += 2;
        } else if (r.mgDl < 80) {
          score += (8 * weight).round();
          reasons.add('اندازه‌گیری نزدیک به محدوده پایین');
          evidence++;
        }
      }

      for (final e in events) {
        final weight = _ageWeight(start, e.time);
        if (weight == 0 ||
            _clockDistance(minute, e.time.hour * 60 + e.time.minute) > 90) {
          continue;
        }

        score += ((e.measuredMgDl != null &&
                    e.measuredMgDl! < level2
                ? 40
                : 28) *
            weight).round();
        evidence += 2;
        reasons.add('سابقه افت قند ثبت‌شده در این ساعت');
      }

      final latestMeal = _latestMealBefore(start, meals);
      if (latestMeal != null) {
        final mealGap = start.difference(latestMeal).inMinutes;
        if (mealGap >= 300) {
          score += 16;
          evidence++;
          reasons.add('فاصله طولانی از آخرین وعده ثبت‌شده');
        } else if (mealGap >= 240) {
          score += 8;
          evidence++;
          reasons.add('فاصله نسبتاً طولانی از آخرین وعده ثبت‌شده');
        }
      }

      for (final a in activities) {
        final elapsed = start.difference(a.time);
        if (elapsed.isNegative || elapsed > const Duration(hours: 4)) continue;
        score += a.intensity == 'high'
            ? 14
            : a.intensity == 'medium'
                ? 8
                : 3;
        evidence++;
        reasons.add('فعالیت بدنی اخیر');
        break;
      }

      if (_sleeping(minute, profile) && profile.nighttimeHypo) {
        score += 10;
        evidence++;
        reasons.add('سابقه افت قند شبانه');
      }

      if (profile.historyOfHypo) {
        score += 4;
        evidence++;
      }

      if (profile.usesInsulin || profile.usesGlucoseLoweringMedication) {
        score += 4;
        evidence++;
        reasons.add('اطلاعات دارویی ثبت‌شده');
      }

      final ordered = [...readings]
        ..sort((a, b) => a.time.compareTo(b.time));

      if (ordered.length >= 2) {
        final a = ordered[ordered.length - 2];
        final b = ordered.last;
        final mins = b.time.difference(a.time).inMinutes;
        final trendWeight = _ageWeight(start, b.time);

        if (mins > 0 && mins <= 240 && trendWeight > 0) {
          final slope = (b.mgDl - a.mgDl) / (mins / 60.0);
          if (slope <= -20) {
            score += (12 * trendWeight).round();
            evidence += 2;
            reasons.add('روند نزولی سریع');
          } else if (slope <= -10) {
            score += (6 * trendWeight).round();
            evidence++;
            reasons.add('روند نزولی');
          }
        }
      }

      final wakeMinute = profile.wakeHour * 60 + profile.wakeMinute;
      if (minute == wakeMinute && profile.fastingGlucose != null) {
        if (profile.fastingGlucose! < level1) {
          score += 20;
          evidence++;
          reasons.add('قند ناشتا اولیه پایین ثبت شده');
        } else if (profile.fastingGlucose! < 80) {
          score += 8;
          evidence++;
        }
      }

      final evidenceCoverage = (evidence / 6).clamp(0.0, 0.95).toDouble();

      // A window must have either strong direct evidence or at least two
      // independent pieces of contextual evidence. This avoids turning one
      // weak heuristic (such as a meal gap) into a medical-looking alert.
      if (score >= 55 || (score >= 30 && evidence >= 2)) {
        raw.add(
          RiskWindow(
            start: start,
            end: start.add(const Duration(minutes: 30)),
            score: score.clamp(0, 100).toInt(),
            level: classify(score),
            evidenceCoverage: evidenceCoverage,
            reason: reasons.toSet().take(3).join('، '),
          ),
        );
      }
    }

    if (raw.isEmpty) return const [];

    final merged = <RiskWindow>[];
    var current = raw.first;

    for (final next in raw.skip(1)) {
      if (next.start.difference(current.end).inMinutes <= 30) {
        final maxScore = math.max(current.score, next.score);
        current = RiskWindow(
          start: current.start,
          end: next.end,
          score: maxScore,
          level: classify(maxScore),
          evidenceCoverage:
              math.max(current.evidenceCoverage, next.evidenceCoverage).toDouble(),
          reason: current.reason + '؛ ' + next.reason,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    return merged;
  }
}
