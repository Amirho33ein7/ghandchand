import 'package:flutter/material.dart';

import 'models.dart';

class ProfileEditPage extends StatefulWidget {
  final UserProfile profile;
  final Future<void> Function(UserProfile) onSave;

  const ProfileEditPage({
    super.key,
    required this.profile,
    required this.onSave,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController name;
  late final TextEditingController fasting;
  late final TextEditingController nonFasting;
  late TimeOfDay sleep;
  late TimeOfDay wake;
  late String type;
  late bool history;
  late bool night;
  late bool insulin;
  late bool meds;
  late int meals;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    name = TextEditingController(text: p.name);
    fasting = TextEditingController(
      text: p.fastingGlucose?.toStringAsFixed(0) ?? '',
    );
    nonFasting = TextEditingController(
      text: p.nonFastingGlucose?.toStringAsFixed(0) ?? '',
    );
    sleep = TimeOfDay(hour: p.sleepHour, minute: p.sleepMinute);
    wake = TimeOfDay(hour: p.wakeHour, minute: p.wakeMinute);
    type = p.diabetesType ?? 'نمی‌دانم';
    history = p.historyOfHypo;
    night = p.nighttimeHypo;
    insulin = p.usesInsulin;
    meds = p.usesGlucoseLoweringMedication;
    meals = p.mealsPerDay.clamp(1, 6);
  }

  @override
  void dispose() {
    name.dispose();
    fasting.dispose();
    nonFasting.dispose();
    super.dispose();
  }

  Future<void> pickTime(bool isSleep) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isSleep ? sleep : wake,
    );
    if (selected == null) return;
    setState(() {
      if (isSleep) {
        sleep = selected;
      } else {
        wake = selected;
      }
    });
  }

  double? parse(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام را وارد کنید.')),
      );
      return;
    }

    final fast = parse(fasting.text);
    final non = parse(nonFasting.text);

    if ((fasting.text.trim().isNotEmpty && fast == null) ||
        (nonFasting.text.trim().isNotEmpty && non == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مقدار قند باید عددی باشد.')),
      );
      return;
    }

    if ((fast != null && (fast <= 0 || fast > 1000)) ||
        (non != null && (non <= 0 || non > 1000))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مقدار قند خارج از محدوده معتبر ورودی است.')),
      );
      return;
    }

    final updated = UserProfile(
      id: widget.profile.id,
      name: name.text.trim(),
      fastingGlucose: fast,
      nonFastingGlucose: non,
      sleepHour: sleep.hour,
      sleepMinute: sleep.minute,
      wakeHour: wake.hour,
      wakeMinute: wake.minute,
      glucoseUnit: widget.profile.glucoseUnit,
      diabetesType: type,
      historyOfHypo: history,
      nighttimeHypo: night,
      usesInsulin: insulin,
      usesGlucoseLoweringMedication: meds,
      mealsPerDay: meals,
    );

    await widget.onSave(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ویرایش اطلاعات و برنامه')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'هر زمان آزمایش جدید انجام شد، مقادیر زیر را به‌روزرسانی کنید. برنامه بعد از ذخیره، زمان‌بندی وعده‌ها و اعلان‌ها را دوباره محاسبه می‌کند.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'نام',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fasting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'آخرین قند ناشتا',
                suffixText: 'mg/dL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nonFasting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'آخرین قند غیرناشتا / تصادفی',
                suffixText: 'mg/dL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'قند غیرناشتا بسته به زمان اندازه‌گیری و نوع آزمایش تفسیر متفاوتی دارد؛ اپ آن را به‌تنهایی تشخیص پزشکی تلقی نمی‌کند.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('ساعت خواب'),
                    trailing: Text(sleep.format(context)),
                    onTap: () => pickTime(true),
                  ),
                  ListTile(
                    title: const Text('ساعت بیداری'),
                    trailing: Text(wake.format(context)),
                    onTap: () => pickTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'نوع ۱', child: Text('نوع ۱')),
                DropdownMenuItem(value: 'نوع ۲', child: Text('نوع ۲')),
                DropdownMenuItem(value: 'سایر', child: Text('سایر')),
                DropdownMenuItem(value: 'نمی‌دانم', child: Text('نمی‌دانم')),
              ],
              onChanged: (v) => setState(() => type = v ?? type),
              decoration: const InputDecoration(
                labelText: 'نوع دیابت',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              title: const Text('سابقه افت قند دارم'),
              value: history,
              onChanged: (v) => setState(() => history = v),
            ),
            SwitchListTile(
              title: const Text('سابقه افت قند شبانه دارم'),
              value: night,
              onChanged: (v) => setState(() => night = v),
            ),
            SwitchListTile(
              title: const Text('انسولین مصرف می‌کنم'),
              value: insulin,
              onChanged: (v) => setState(() => insulin = v),
            ),
            SwitchListTile(
              title: const Text('داروی کاهش قند مصرف می‌کنم'),
              value: meds,
              onChanged: (v) => setState(() => meds = v),
            ),
            Text('تعداد وعده‌های پایه: $meals'),
            Slider(
              min: 1,
              max: 6,
              divisions: 5,
              value: meals.toDouble(),
              onChanged: (v) => setState(() => meals = v.round()),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.refresh),
              label: const Text('ذخیره و محاسبه مجدد برنامه'),
            ),
          ],
        ),
      ),
    );
  }
}
