import 'package:flutter/material.dart';

class SafetyAlertPage extends StatelessWidget {
  final String payload;
  final Future<void> Function() onRegisterGlucose;

  const SafetyAlertPage({
    super.key,
    required this.payload,
    required this.onRegisterGlucose,
  });

  double? get measuredValue {
    const prefix = 'measured_low:';
    if (!payload.startsWith(prefix)) return null;
    return double.tryParse(payload.substring(prefix.length));
  }

  String? get mealTitle {
    const prefix = 'meal:';
    if (!payload.startsWith(prefix)) return null;
    return payload.substring(prefix.length);
  }

  bool get measuredLow => measuredValue != null;
  bool get isMealReminder => mealTitle != null;
  bool get severeMeasuredLow => measuredValue != null && measuredValue! < 54;

  @override
  Widget build(BuildContext context) {
    if (isMealReminder) {
      return Scaffold(
        appBar: AppBar(title: const Text('یادآوری وعده غذایی')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.restaurant_outlined, size: 88),
              const SizedBox(height: 20),
              Text(
                '🍽️ زمان ' + mealTitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'این اعلان بر اساس برنامه زمانی شخصی شما ساخته شده است. مقدار و نوع غذا را طبق برنامه درمانی یا عادت معمول خود تعیین کنید. اگر قندتان پایین است، طبق برنامه درمانی خود اقدام کنید.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
        ),
      );
    }

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
                  ? (severeMeasuredLow
                      ? 'قند خون بسیار پایین ثبت شده است'
                      : 'قند خون پایین ثبت شده است')
                  : 'زمان بررسی قند خون',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              measuredLow
                  ? (severeMeasuredLow
                      ? 'یک اندازه‌گیری کمتر از 54 mg/dL ثبت شده است. طبق برنامه درمانی خود اقدام کنید. اگر فرد هوشیار نیست یا نمی‌تواند به‌صورت ایمن چیزی مصرف کند، چیزی از راه دهان ندهید و از کمک فوری استفاده کنید.'
                      : 'یک اندازه‌گیری کمتر از 70 mg/dL ثبت شده است. طبق برنامه درمانی خود اقدام کنید و طبق دستور پزشک خود قند را دوباره بررسی کنید.')
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