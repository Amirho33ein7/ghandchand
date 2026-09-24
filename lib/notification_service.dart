import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'navigation.dart';
import 'meal_scheduler.dart';
import 'notification_planner.dart';
import 'risk_engine.dart';

class NotificationScheduleReport {
  final int expectedMealNotifications;
  final int pendingMealNotifications;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;

  const NotificationScheduleReport({
    required this.expectedMealNotifications,
    required this.pendingMealNotifications,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
  });

  bool get healthy =>
      notificationsEnabled &&
      pendingMealNotifications >= expectedMealNotifications;
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future<void>.value();

  static const channelId = 'low_guard_alerts';
  static const mealChannelId = 'low_guard_meals';
  static const firstRecurringMealId = 210000;
  static const maxMealSlots = 6;
  static const testNotificationId = 299999;

  Future<void> _runSerialized(Future<void> Function() action) async {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    try {
      await previous.catchError((_) {});
      await action();
      done.complete();
    } catch (error, stackTrace) {
      done.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/app_icon'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          handleNotificationPayload(response.payload),
    );

    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      handleNotificationPayload(launch?.notificationResponse?.payload);
    }

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'هشدارهای نگهبان قند',
        description: 'هشدارهای پایش و افت قند خون',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        mealChannelId,
        'یادآوری وعده‌های غذایی',
        description: 'یادآوری زمان وعده‌های محاسبه‌شده توسط برنامه',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android?.requestNotificationsPermission();
    _ready = true;
  }

  Future<bool> notificationsEnabled() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<bool?> requestNotificationPermission() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  Future<void> openNotificationSettings() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.openAppNotificationSettings();
  }

  Future<bool> exactPermission() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  Future<bool> canExact() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  NotificationDetails details(RiskLevel level) => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'هشدارهای نگهبان قند',
          channelDescription: 'هشدارهای پایش و افت قند خون',
          importance: level.index >= RiskLevel.high.index
              ? Importance.max
              : Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          autoCancel: false,
        ),
      );

  NotificationDetails mealDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          mealChannelId,
          'یادآوری وعده‌های غذایی',
          channelDescription: 'یادآوری زمان وعده‌های محاسبه‌شده توسط برنامه',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          autoCancel: true,
        ),
      );

  int riskNotificationId(RiskWindow w) {
    final dayStart = DateTime(w.start.year, w.start.month, w.start.day);
    final halfHour = w.start.difference(dayStart).inMinutes ~/ 30;
    return 100000 + halfHour;
  }

  int recurringMealNotificationId(int index) =>
      NotificationPlanner.mealId(index);

  tz.TZDateTime _nextMealOccurrence(MealPlanEntry entry) {
    final now = tz.TZDateTime.now(tz.local);
    final candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      entry.time.hour,
      entry.time.minute,
    );

    if (candidate.isAfter(now)) return candidate;

    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      entry.time.hour,
      entry.time.minute,
    );
  }

  Future<void> _scheduleRiskWindow(
    RiskWindow w, {
    required AndroidScheduleMode mode,
  }) async {
    final date = tz.TZDateTime.from(w.start, tz.local);
    if (!date.isAfter(tz.TZDateTime.now(tz.local))) return;

    await plugin.zonedSchedule(
      id: riskNotificationId(w),
      title: w.level.index >= RiskLevel.high.index
          ? '⚠️ زمان بررسی قند خون'
          : 'یادآوری بررسی قند خون',
      body:
          'بر اساس داده‌های ثبت‌شده، ریسک افت قند در این بازه بیشتر برآورد شده است. در صورت امکان قند خون خود را بررسی کنید.',
      scheduledDate: date,
      notificationDetails: details(w.level),
      androidScheduleMode: mode,
      payload: 'risk:' + w.start.toIso8601String(),
    );
  }

  Future<void> _scheduleRecurringMeal(
    MealPlanEntry entry, {
    required int index,
    required AndroidScheduleMode mode,
  }) async {
    final next = _nextMealOccurrence(entry);

    await plugin.zonedSchedule(
      id: recurringMealNotificationId(index),
      title: '🍽️ زمان ' + entry.title,
      body:
          'الان زمان وعده برنامه‌ریزی‌شده است. مقدار و نوع غذا را طبق برنامه شخصی یا درمانی خود تعیین کنید.',
      scheduledDate: next,
      notificationDetails: mealDetails(),
      androidScheduleMode: mode,
      payload: 'meal:' + entry.title,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _clearRiskWindowNotifications() async {
    for (var i = 0; i < 48; i++) {
      await plugin.cancel(id: 100000 + i);
    }
  }

  Future<void> _clearMealNotifications() async {
    final pending = await plugin.pendingNotificationRequests();
    final mealIds = pending
        .where(
          (request) =>
              request.payload?.startsWith('meal:') == true ||
              (request.id >= firstRecurringMealId &&
                  request.id < firstRecurringMealId + maxMealSlots),
        )
        .map((request) => request.id)
        .toSet();

    for (final id in mealIds) {
      await plugin.cancel(id: id);
    }
  }

  Future<void> _verifyMealSchedule(
    List<MealPlanEntry> entries, {
    required AndroidScheduleMode mode,
  }) async {
    if (entries.isEmpty) return;

    final expected = <int>{
      for (var i = 0; i < entries.length && i < maxMealSlots; i++)
        recurringMealNotificationId(i),
    };

    for (var attempt = 0; attempt < 2; attempt++) {
      final pending = await plugin.pendingNotificationRequests();
      final pendingIds = pending.map((e) => e.id).toSet();
      final missing = expected.where((id) => !pendingIds.contains(id));

      if (missing.isEmpty) return;

      for (final id in missing) {
        final index = id - firstRecurringMealId;
        if (index >= 0 &&
            index < entries.length &&
            index < maxMealSlots) {
          await _scheduleRecurringMeal(
            entries[index],
            index: index,
            mode: mode,
          );
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    final pending = await plugin.pendingNotificationRequests();
    final pendingIds = pending.map((e) => e.id).toSet();
    final missing = expected.where((id) => !pendingIds.contains(id)).toList();

    if (missing.isNotEmpty) {
      throw StateError(
        'Meal notification scheduling failed for ids: ' + missing.join(', '),
      );
    }
  }

  Future<NotificationScheduleReport> rescheduleDayPlan({
    required List<RiskWindow> windows,
    required List<MealPlanEntry> meals,
  }) async {
    await init();

    late NotificationScheduleReport report;

    await _runSerialized(() async {
      final notificationsAllowed = await notificationsEnabled();
      final exactAllowed = await canExact();
      final mode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _clearRiskWindowNotifications();
      for (final w in windows.take(6)) {
        await _scheduleRiskWindow(w, mode: mode);
      }

      // Remove current reminders and any legacy meal reminders created
      // by older app versions before rebuilding the new daily plan.
      await _clearMealNotifications();

      final count = meals.length.clamp(0, maxMealSlots).toInt();
      for (var i = 0; i < count; i++) {
        await _scheduleRecurringMeal(meals[i], index: i, mode: mode);
      }

      await _verifyMealSchedule(
        meals.take(maxMealSlots).toList(),
        mode: mode,
      );

      final pendingMeals = await plugin.pendingNotificationRequests();
      final mealIds = <int>{
        for (var i = 0; i < count; i++) recurringMealNotificationId(i),
      };

      report = NotificationScheduleReport(
        expectedMealNotifications: count,
        pendingMealNotifications:
            pendingMeals.where((e) => mealIds.contains(e.id)).length,
        notificationsEnabled: notificationsAllowed,
        exactAlarmsAllowed: exactAllowed,
      );
    });

    return report;
  }

  Future<void> scheduleTestNotification() async {
    await init();
    await plugin.cancel(id: testNotificationId);
    await plugin.show(
      id: testNotificationId,
      title: '✅ تست اعلان نگهبان قند',
      body: 'اگر این پیام را می‌بینید، اعلان‌های برنامه فعال و قابل دریافت هستند.',
      notificationDetails: mealDetails(),
      payload: 'test_notification',
    );
  }

  Future<void> showLow(double mgDl) async {
    await init();
    final severe = mgDl < RiskEngine.level2;
    await plugin.show(
      id: 900001,
      title: severe ? '⚠️ قند خون بسیار پایین ثبت شد' : '⚠️ قند خون پایین ثبت شد',
      body: severe
          ? 'کمتر از 54 mg/dL ثبت شده است. طبق برنامه درمانی خود اقدام کنید و اگر فرد هوشیار نیست یا نمی‌تواند ایمن چیزی مصرف کند، کمک فوری بگیرید.'
          : 'کمتر از 70 mg/dL ثبت شده است. طبق برنامه درمانی خود اقدام کنید و دوباره قند را بررسی کنید.',
      notificationDetails:
          details(severe ? RiskLevel.veryHigh : RiskLevel.high),
      payload: 'measured_low:' + mgDl.toString(),
    );
  }

  Future<void> scheduleToday(List<RiskWindow> windows) async {
    await init();
    await _runSerialized(() async {
      final exactAllowed = await canExact();
      final mode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _clearRiskWindowNotifications();
      for (final w in windows.take(6)) {
        await _scheduleRiskWindow(w, mode: mode);
      }
    });
  }

  Future<void> scheduleMealPlan(List<MealPlanEntry> entries) async {
    await init();
    await _runSerialized(() async {
      final exactAllowed = await canExact();
      final mode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _clearMealNotifications();

      final count = entries.length.clamp(0, maxMealSlots).toInt();
      for (var i = 0; i < count; i++) {
        await _scheduleRecurringMeal(entries[i], index: i, mode: mode);
      }

      await _verifyMealSchedule(
        entries.take(maxMealSlots).toList(),
        mode: mode,
      );
    });
  }

  Future<void> scheduleDayPlan({
    required List<RiskWindow> windows,
    required List<MealPlanEntry> meals,
  }) async {
    await rescheduleDayPlan(windows: windows, meals: meals);
  }
}
