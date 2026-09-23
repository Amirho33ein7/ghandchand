import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'navigation.dart';
import 'meal_scheduler.dart';
import 'risk_engine.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const channelId = 'low_guard_alerts';
  static const mealChannelId = 'low_guard_meals';

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

  int mealNotificationId(MealPlanEntry entry, int index) {
    final serial = DateTime.utc(
      entry.time.year,
      entry.time.month,
      entry.time.day,
    ).difference(DateTime.utc(2020, 1, 1)).inDays;
    return 210000 + (serial * 10) + index;
  }

  Future<void> schedule(RiskWindow w) async {
    await init();
    final date = tz.TZDateTime.from(w.start, tz.local);
    if (!date.isAfter(tz.TZDateTime.now(tz.local))) return;

    final mode = await canExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

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

  Future<void> scheduleMeal(
    MealPlanEntry entry, {
    required int index,
  }) async {
    await init();
    final date = tz.TZDateTime.from(entry.time, tz.local);
    if (!date.isAfter(tz.TZDateTime.now(tz.local))) return;

    final mode = await canExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await plugin.zonedSchedule(
      id: mealNotificationId(entry, index),
      title: '🍽️ زمان ' + entry.title,
      body:
          'الان زمان وعده برنامه‌ریزی‌شده است. اگر قندتان پایین است، طبق برنامه درمانی خود اقدام کنید.',
      scheduledDate: date,
      notificationDetails: mealDetails(),
      androidScheduleMode: mode,
      payload: 'meal:' + entry.title,
    );
  }

  int recurringMealNotificationId(int index) => 210000 + index;

  DateTime _nextMealOccurrence(DateTime now, MealPlanEntry entry) {
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

  Future<void> scheduleRecurringMeal(
    MealPlanEntry entry, {
    required int index,
  }) async {
    await init();
    final next = _nextMealOccurrence(DateTime.now(), entry);
    final date = tz.TZDateTime.from(next, tz.local);
    final mode = await canExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await plugin.zonedSchedule(
      id: recurringMealNotificationId(index),
      title: '🍽️ زمان ' + entry.title,
      body:
          'الان زمان وعده برنامه‌ریزی‌شده است. مقدار و نوع غذا را طبق برنامه شخصی یا درمانی خود تعیین کنید.',
      scheduledDate: date,
      notificationDetails: mealDetails(),
      androidScheduleMode: mode,
      payload: 'meal:' + entry.title,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleDailyMealPlan(List<MealPlanEntry> entries) async {
    await clearMealNotifications();
    final count = entries.length.clamp(0, 6).toInt();
    for (var i = 0; i < count; i++) {
      await scheduleRecurringMeal(entries[i], index: i);
    }
  }

  Future<void> scheduleTestNotification() async {
    await init();
    final now = DateTime.now().add(const Duration(seconds: 10));
    final date = tz.TZDateTime.from(now, tz.local);
    final mode = await canExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await plugin.zonedSchedule(
      id: 299999,
      title: '✅ تست اعلان نگهبان قند',
      body: 'اگر این پیام را می‌بینید، اعلان‌های برنامه فعال و قابل دریافت هستند.',
      scheduledDate: date,
      notificationDetails: mealDetails(),
      androidScheduleMode: mode,
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

  Future<void> clearRiskWindowNotifications() async {
    await init();
    for (var i = 0; i < 48; i++) {
      await plugin.cancel(id: 100000 + i);
    }
  }

  Future<void> clearMealNotifications() async {
    await init();
    for (var i = 210000; i < 220000; i++) {
      await plugin.cancel(id: i);
    }
  }

  Future<void> scheduleToday(List<RiskWindow> windows) async {
    await clearRiskWindowNotifications();
    for (final w in windows.take(6)) {
      await schedule(w);
    }
  }

  Future<void> scheduleMealPlan(List<MealPlanEntry> entries) async {
    await scheduleDailyMealPlan(entries);
  }

  Future<void> scheduleDayPlan({
    required List<RiskWindow> windows,
    required List<MealPlanEntry> meals,
  }) async {
    await scheduleToday(windows);
    await scheduleDailyMealPlan(meals);
  }
}
