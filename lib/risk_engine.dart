import 'dart:math' as math;
import 'models.dart';

class RiskEngine {
  static const level1 = 70.0;
  static const level2 = 54.0;

  static RiskLevel classify(num score) => score >= 80
      ? RiskLevel.veryHigh
      : score >= 60
          ? RiskLevel.high
          : score >= 30
              ? RiskLevel.medium
              : RiskLevel.low;

  static String glucoseBand(double mgDl) => mgDl < level2
      ? 'افت قند سطح ۲'
      : mgDl < level1
          ? 'افت قند سطح ۱'
          : mgDl <= 180
              ? 'محدوده هدف عمومی'
              : 'بالاتر از محدوده هدف عمومی';

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
        if (_clockDistance(minute, r.time.hour * 60 + r.time.minute) <= 60) {
          evidence++;
          if (r.mgDl < level2) {
            score += 45;
            reasons.add('سابقه قند کمتر از 54');
          } else if (r.mgDl < level1) {
            score += 30;
            reasons.add('سابقه قند کمتر از 70');
          } else if (r.mgDl < 80) {
            score += 8;
            reasons.add('اندازه‌گیری نزدیک به محدوده پایین');
          }
        }
      }

      for (final e in events) {
        if (_clockDistance(minute, e.time.hour * 60 + e.time.minute) <= 90) {
          score += e.measuredMgDl != null && e.measuredMgDl! < level2 ? 40 : 28;
          evidence += 2;
          reasons.add('سابقه افت قند ثبت‌شده در این ساعت');
        }
      }

      if (meals.isNotEmpty) {
        final gap = meals.map((m) => _clockDistance(
              minute,
              m.time.hour * 60 + m.time.minute,
            )).reduce(math.min);
        if (gap >= 300) {
          score += 16;
          evidence++;
          reasons.add('فاصله طولانی از وعده ثبت‌شده');
        } else if (gap >= 240) {
          score += 8;
          evidence++;
          reasons.add('فاصله نسبتاً طولانی از وعده ثبت‌شده');
        }
      }

      for (final a in activities) {
        var elapsed = minute - (a.time.hour * 60 + a.time.minute);
        if (elapsed < 0) elapsed += 1440;
        if (elapsed <= 240) {
          score += a.intensity == 'high' ? 14 : a.intensity == 'medium' ? 8 : 3;
          evidence++;
          reasons.add('فعالیت بدنی اخیر');
          break;
        }
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
        reasons.add('نیاز به پایش دقیق‌تر بر اساس اطلاعات ثبت‌شده');
      }

      final ordered = [...readings]..sort((a, b) => a.time.compareTo(b.time));
      if (ordered.length >= 2) {
        final a = ordered[ordered.length - 2];
        final b = ordered.last;
        final mins = b.time.difference(a.time).inMinutes;
        if (mins > 0 && mins <= 240) {
          final slope = (b.mgDl - a.mgDl) / (mins / 60);
          if (slope <= -20) {
            score += 12;
            evidence += 2;
            reasons.add('روند نزولی سریع');
          } else if (slope <= -10) {
            score += 6;
            evidence++;
            reasons.add('روند نزولی');
          }
        }
      }

      if (minute == profile.wakeHour * 60 + profile.wakeMinute &&
          profile.fastingGlucose != null &&
          profile.fastingGlucose! < level1) {
        score += 20;
        evidence++;
        reasons.add('قند ناشتا اولیه پایین ثبت شده');
      }

      final confidence = evidence == 0
          ? 0.0
          : (evidence / (evidence + 5)).clamp(0.0, 0.95).toDouble();

      if (score >= 30) {
        raw.add(
          RiskWindow(
            start: start,
            end: start.add(const Duration(minutes: 30)),
            score: score.clamp(0, 100).toInt(),
            level: classify(score),
            confidence: confidence,
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
        final s = math.max(current.score, next.score);
        current = RiskWindow(
          start: current.start,
          end: next.end,
          score: s,
          level: classify(s),
          confidence: math.max(current.confidence, next.confidence).toDouble(),
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
