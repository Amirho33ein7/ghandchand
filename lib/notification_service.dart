import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'navigation.dart';
import 'risk_engine.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const channelId = 'low_guard_alerts';

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
    await android?.requestNotificationsPermission();
    _ready = true;
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
          channelDescription: 'هشدارهای مهم پایش قند خون',
          importance: level.index >= RiskLevel.high.index ? Importance.max : Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          autoCancel: false,
        ),
      );

  int riskNotificationId(RiskWindow w) {
    final dayStart = DateTime(w.start.year, w.start.month, w.start.day);
    final halfHour = w.start.difference(dayStart).inMinutes ~/ 30;
    return 100000 + halfHour;
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
      title: w.level.index >= RiskLevel.high.index ? '⚠️ زمان بررسی قند خون' : 'یادآوری بررسی قند خون',
      body: 'بر اساس داده‌های ثبت‌شده، ریسک افت قند در این بازه بیشتر برآورد شده است. در صورت امکان قند خون خود را بررسی کنید.',
      scheduledDate: date,
      notificationDetails: details(w.level),
      androidScheduleMode: mode,
      payload: 'risk:' + w.start.toIso8601String(),
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
      notificationDetails: details(severe ? RiskLevel.veryHigh : RiskLevel.high),
      payload: 'measured_low:' + mgDl.toString(),
    );
  }

  Future<void> clearRiskWindowNotifications() async {
    await init();
    for (var i = 0; i < 48; i++) {
      await plugin.cancel(id: 100000 + i);
    }
  }

  Future<void> scheduleToday(List<RiskWindow> windows) async {
    await clearRiskWindowNotifications();
    for (final w in windows.take(6)) {
      await schedule(w);
    }
  }
}
