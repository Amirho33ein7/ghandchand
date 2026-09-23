import 'package:flutter/material.dart';

class SafetyAlertPage extends StatelessWidget {
  final String payload;
  final Future<void> Function() onRegisterGlucose;

  const SafetyAlertPage({
    super.key,
    required this.payload,
    required this.onRegisterGlucose,
  });

  bool get measuredLow => payload.startsWith('measured_low:');

  @override
  Widget build(BuildContext context) {
    final severe = payload.startsWith('measured_low:54') ||
        payload.startsWith('measured_low:53') ||
        payload.startsWith('measured_low:52') ||
        payload.startsWith('measured_low:51') ||
        payload.startsWith('measured_low:50');

    return Scaffold(
      appBar: AppBar(title: const Text('هشدار قند خون')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              measuredLow
                  ? Icons.warning_amber_rounded
                  : Icons.notifications_active_outlined,
              size: 88,
              color: measuredLow ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              measuredLow
                  ? (severe
                      ? 'قند خون بسیار پایین ثبت شده است'
                      : 'قند خون پایین ثبت شده است')
                  : 'زمان بررسی قند خون',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              measuredLow
                  ? (severe
                      ? 'یک اندازه‌گیری بسیار پایین ثبت شده است. طبق برنامه درمانی خود اقدام کنید. اگر فرد هوشیار نیست یا نمی‌تواند به‌صورت ایمن چیزی مصرف کند، چیزی از راه دهان ندهید و از کمک فوری استفاده کنید.'
                      : 'یک اندازه‌گیری پایین ثبت شده است. طبق برنامه درمانی خود اقدام کنید و طبق دستور پزشک خود قند را دوباره بررسی کنید.')
                  : 'این هشدار بر اساس داده‌های ثبت‌شده و موتور ریسک شخصی برنامه ایجاد شده است. در صورت امکان قند خون خود را بررسی کنید.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await onRegisterGlucose();
              },
              icon: const Icon(Icons.bloodtype_outlined),
              label: const Text('الان قندم را اندازه گرفتم'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }
}
