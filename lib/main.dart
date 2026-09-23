import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'alert_page.dart';
import 'navigation.dart';
import 'database.dart';
import 'models.dart';
import 'notification_service.dart';
import 'risk_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const LowGuardApp());
}

class LowGuardApp extends StatelessWidget {
  const LowGuardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'نگهبان قند',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const RootPage(),
      );
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  UserProfile? profile;
  List<GlucoseReading> readings = [];
  List<MealEntry> meals = [];
  List<ActivityEntry> activities = [];
  List<HypoglycemiaEvent> events = [];
  List<RiskWindow> windows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    notificationPayload.addListener(_handleNotificationPayload);
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationPayload());
  }

  @override
  void dispose() {
    notificationPayload.removeListener(_handleNotificationPayload);
    super.dispose();
  }

  void _handleNotificationPayload() {
    final payload = notificationPayload.value;
    if (!mounted || payload == null || payload.isEmpty) return;
    notificationPayload.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SafetyAlertPage(
            payload: payload,
            onRegisterGlucose: addReading,
          ),
        ),
      );
    });
  }

  Future<void> load() async {
    final db = DatabaseService.instance;
    final p = await db.getProfile();
    final r = await db.glucose();
    final m = await db.meals();
    final a = await db.activities();
    final h = await db.hypos();
    if (!mounted) return;
    setState(() {
      profile = p;
      readings = r;
      meals = m;
      activities = a;
      events = h;
      loading = false;
    });
    if (p != null) recalc();
  }

  void recalc() {
    if (profile == null) return;
    final result = RiskEngine.calculateDay(
      day: DateTime.now(),
      profile: profile!,
      readings: readings,
      meals: meals,
      activities: activities,
      events: events,
    );
    if (mounted) setState(() => windows = result);
  }

  Future<void> complete(UserProfile p) async {
    await DatabaseService.instance.saveProfile(p);
    await load();
  }

  Future<void> addReading() async {
    final r = await showDialog<GlucoseReading>(
      context: context,
      builder: (_) => const GlucoseDialog(),
    );
    if (r == null) return;
    await DatabaseService.instance.addGlucose(r);
    if (r.mgDl < RiskEngine.level1) {
      await NotificationService.instance.showLow(r.mgDl);
    }
    await load();
  }

  Future<void> addMeal() async {
    final r = await showDialog<MealEntry>(
      context: context,
      builder: (_) => const MealDialog(),
    );
    if (r == null) return;
    await DatabaseService.instance.addMeal(r);
    await load();
  }

  Future<void> addActivity() async {
    final r = await showDialog<ActivityEntry>(
      context: context,
      builder: (_) => const ActivityDialog(),
    );
    if (r == null) return;
    await DatabaseService.instance.addActivity(r);
    await load();
  }

  Future<void> addHypo() async {
    final r = await showDialog<HypoglycemiaEvent>(
      context: context,
      builder: (_) => const HypoDialog(),
    );
    if (r == null) return;
    await DatabaseService.instance.addHypo(r);
    await load();
  }

  Future<void> scheduleToday() async {
    if (windows.isEmpty) {
      snack('هنوز بازه‌ای با ریسک کافی برای هشدار وجود ندارد.');
      return;
    }
    await NotificationService.instance.scheduleToday(windows);
    snack('هشدارهای امروز زمان‌بندی شدند.');
  }

  Future<void> exact() async {
    final ok = await NotificationService.instance.exactPermission();
    snack(
      ok
          ? 'مجوز زمان‌بندی دقیق فعال شد.'
          : 'مجوز فعال نشد؛ زمان‌بندی غیر دقیق استفاده می‌شود.',
    );
  }

  Future<void> exportData() async {
    final data = <String, Object?>{
      'profile': profile?.toMap(),
      'glucose': readings.map((e) => e.toMap()).toList(),
      'meals': meals.map((e) => e.toMap()).toList(),
      'activities': activities.map((e) => e.toMap()).toList(),
      'hypoglycemia_events': events.map((e) => e.toMap()).toList(),
    };
    await SharePlus.instance.share(
      ShareParams(
        text: JsonEncoder.withIndent('  ').convert(data),
        title: 'داده‌های نگهبان قند',
      ),
    );
  }

  void snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) return OnboardingPage(onDone: complete);
    return HomePage(
      profile: profile!,
      readings: readings,
      windows: windows,
      addReading: addReading,
      addMeal: addMeal,
      addActivity: addActivity,
      addHypo: addHypo,
      scheduleToday: scheduleToday,
      exact: exact,
      exportData: exportData,
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final Future<void> Function(UserProfile) onDone;
  const OnboardingPage({super.key, required this.onDone});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final page = PageController();
  final name = TextEditingController();
  final fasting = TextEditingController();
  final nonFasting = TextEditingController();
  int index = 0;
  TimeOfDay sleep = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay wake = const TimeOfDay(hour: 7, minute: 0);
  String type = 'نمی‌دانم';
  bool history = false;
  bool night = false;
  bool insulin = false;
  bool meds = false;
  int meals = 3;

  Future<void> pickTime(bool isSleep) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isSleep ? sleep : wake,
    );
    if (t == null) return;
    setState(() {
      if (isSleep) {
        sleep = t;
      } else {
        wake = t;
      }
    });
  }

  Future<void> next() async {
    if (index == 0 && name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام را وارد کنید.')),
      );
      return;
    }
    if (index == 1 &&
        fasting.text.trim().isNotEmpty &&
        double.tryParse(fasting.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قند ناشتا باید عددی باشد.')),
      );
      return;
    }
    if (index == 2 &&
        nonFasting.text.trim().isNotEmpty &&
        double.tryParse(nonFasting.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قند غیرناشتا باید عددی باشد.')),
      );
      return;
    }

    if (index < 4) {
      setState(() => index++);
      await page.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }

    await widget.onDone(
      UserProfile(
        name: name.text.trim(),
        fastingGlucose: double.tryParse(fasting.text.trim()),
        nonFastingGlucose: double.tryParse(nonFasting.text.trim()),
        sleepHour: sleep.hour,
        sleepMinute: sleep.minute,
        wakeHour: wake.hour,
        wakeMinute: wake.minute,
        diabetesType: type,
        historyOfHypo: history,
        nighttimeHypo: night,
        usesInsulin: insulin,
        usesGlucoseLoweringMedication: meds,
        mealsPerDay: meals,
      ),
    );
  }

  Widget glucoseStep(TextEditingController c, String title) {
    return ListView(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.monitor_heart_outlined, size: 72),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: 'mg/dL',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ListView(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.health_and_safety_rounded,
            size: 90,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          const Text('سلام 👋', textAlign: TextAlign.center, style: TextStyle(fontSize: 28)),
          const SizedBox(height: 12),
          const Text(
            'چند اطلاعات اولیه می‌گیریم تا پایش شخصی ساخته شود. این برنامه جایگزین پزشک یا برنامه درمانی نیست.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'اسم شما چیست؟',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      glucoseStep(fasting, 'قند خون ناشتا معمولاً چقدر است؟'),
      glucoseStep(nonFasting, 'قند خون غیرناشتا معمولاً چقدر است؟'),
      ListView(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.bedtime_outlined, size: 72),
          const SizedBox(height: 20),
          const Text(
            'ساعت تقریبی خواب و بیداری',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text('خواب'),
            trailing: Text(sleep.format(context)),
            onTap: () => pickTime(true),
          ),
          ListTile(
            title: const Text('بیداری'),
            trailing: Text(wake.format(context)),
            onTap: () => pickTime(false),
          ),
        ],
      ),
      ListView(
        children: [
          const Text(
            'اطلاعات تکمیلی (اختیاری)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: const [
              DropdownMenuItem(value: 'نوع ۱', child: Text('نوع ۱')),
              DropdownMenuItem(value: 'نوع ۲', child: Text('نوع ۲')),
              DropdownMenuItem(value: 'سایر', child: Text('سایر')),
              DropdownMenuItem(value: 'نمی‌دانم', child: Text('نمی‌دانم')),
            ],
            onChanged: (v) => setState(() => type = v ?? type),
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
          Text('تعداد تقریبی وعده‌ها: ' + meals.toString()),
          Slider(
            min: 1,
            max: 6,
            divisions: 5,
            value: meals.toDouble(),
            onChanged: (v) => setState(() => meals = v.round()),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('نگهبان قند')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (index + 1) / pages.length),
            Expanded(
              child: PageView(
                controller: page,
                physics: const NeverScrollableScrollPhysics(),
                children: pages
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: p,
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: next,
                  child: Text(
                    index == pages.length - 1 ? 'شروع برنامه' : 'بعدی',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final UserProfile profile;
  final List<GlucoseReading> readings;
  final List<RiskWindow> windows;
  final Future<void> Function() addReading;
  final Future<void> Function() addMeal;
  final Future<void> Function() addActivity;
  final Future<void> Function() addHypo;
  final Future<void> Function() scheduleToday;
  final Future<void> Function() exact;
  final Future<void> Function() exportData;

  const HomePage({
    super.key,
    required this.profile,
    required this.readings,
    required this.windows,
    required this.addReading,
    required this.addMeal,
    required this.addActivity,
    required this.addHypo,
    required this.scheduleToday,
    required this.exact,
    required this.exportData,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text('سلام ' + profile.name),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'خانه', icon: Icon(Icons.home_outlined)),
                Tab(text: 'گزارش', icon: Icon(Icons.insights_outlined)),
                Tab(text: 'ایمنی', icon: Icon(Icons.warning_amber_outlined)),
                Tab(text: 'تنظیمات', icon: Icon(Icons.settings_outlined)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              home(context),
              reports(context),
              safety(context),
              settings(context),
            ],
          ),
        ),
      );

  Widget home(BuildContext context) {
    final latest = readings.isEmpty ? null : readings.first;
    final ordered = [...windows]
      ..sort((a, b) => b.score.compareTo(a.score));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'بازه‌های پرریسک فقط برآورد الگوریتمی هستند و تشخیص قطعی یا دستور درمان نیستند.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('آخرین قند'),
            subtitle: Text(
              latest == null
                  ? 'هنوز ثبت نشده'
                  : latest.mgDl.toStringAsFixed(0) +
                      ' mg/dL • ' +
                      RiskEngine.glucoseBand(latest.mgDl),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'بازه‌های پرریسک امروز',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (ordered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('هنوز داده کافی وجود ندارد.'),
                  )
                else
                  ...ordered.take(4).map(
                        (w) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(clock(w.start) + ' تا ' + clock(w.end)),
                          subtitle: Text(
                            w.level.label +
                                ' • امتیاز ' +
                                w.score.toString() +
                                ' • اطمینان ' +
                                (w.confidence * 100).round().toString() +
                                '%',
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('جزئیات بازه'),
                              content: Text(
                                w.reason +
                                    '

این بازه فقط برای یادآوری بررسی قند است و به معنی نیاز قطعی به غذا یا تغییر درمان نیست.',
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            action(Icons.bloodtype_outlined, 'ثبت قند', addReading),
            action(Icons.restaurant_outlined, 'ثبت غذا', addMeal),
            action(Icons.directions_run_outlined, 'ثبت فعالیت', addActivity),
            action(Icons.warning_amber_rounded, 'ثبت افت قند', addHypo),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: scheduleToday,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('زمان‌بندی هشدارهای امروز'),
        ),
      ],
    );
  }

  Widget reports(BuildContext context) {
    final values = [...readings]..sort((a, b) => a.time.compareTo(b.time));
    final average = values.isEmpty
        ? null
        : values.map((e) => e.mgDl).reduce((a, b) => a + b) / values.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('اندازه‌گیری: ' + values.length.toString())),
            Chip(
              label: Text(
                'افت: ' +
                    values.where((r) => r.mgDl < 70).length.toString(),
              ),
            ),
            if (average != null)
              Chip(label: Text('میانگین: ' + average.toStringAsFixed(1))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: Card(
            child: values.length < 2
                ? const Center(
                    child: Text('برای نمودار حداقل ۲ اندازه‌گیری لازم است.'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: LineChart(
                      LineChartData(
                        minY: 40,
                        maxY: math.max(
                          220,
                          values.map((e) => e.mgDl).reduce(math.max) + 20,
                        ).toDouble(),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            spots: values
                                .asMap()
                                .entries
                                .map(
                                  (e) => FlSpot(
                                    e.key.toDouble(),
                                    e.value.mgDl,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget safety(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SafetyCard(
            title: 'افت قند سطح ۱',
            text: 'کمتر از 70 و حداقل 54 mg/dL.',
          ),
          _SafetyCard(
            title: 'افت قند سطح ۲',
            text: 'کمتر از 54 mg/dL و نیازمند اقدام فوری.',
          ),
          _SafetyCard(
            title: 'افت قند سطح ۳',
            text:
                'رخداد شدید که برای درمان به کمک فرد دیگر نیاز دارد، مستقل از عدد قند.',
          ),
          _SafetyCard(
            title: 'قاعده 15-15',
            text:
                'برای بسیاری از افراد: 15 گرم کربوهیدرات سریع‌الاثر و بررسی مجدد بعد از 15 دقیقه؛ برنامه درمانی پزشک مقدم است.',
          ),
        ],
      );

  Widget settings(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('مجوز زمان‌بندی دقیق'),
            onTap: exact,
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('خروجی داده‌ها'),
            subtitle: const Text('اشتراک‌گذاری JSON محلی'),
            onTap: exportData,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'این برنامه ابزار کمکی است و جایگزین پزشک، تشخیص پزشکی یا برنامه درمانی شخصی نیست.',
            ),
          ),
        ],
      );

  Widget action(
    IconData icon,
    String text,
    Future<void> Function() onTap,
  ) =>
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 8),
              Text(text),
            ],
          ),
        ),
      );

  String clock(DateTime d) =>
      d.hour.toString().padLeft(2, '0') +
      ':' +
      d.minute.toString().padLeft(2, '0');
}

class _SafetyCard extends StatelessWidget {
  final String title;
  final String text;

  const _SafetyCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text),
          ),
        ),
      );
}

class GlucoseDialog extends StatefulWidget {
  const GlucoseDialog({super.key});
  @override
  State<GlucoseDialog> createState() => _GlucoseDialogState();
}

class _GlucoseDialogState extends State<GlucoseDialog> {
  final controller = TextEditingController();
  var contextValue = GlucoseContext.other;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('ثبت قند خون'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'مقدار', suffixText: 'mg/dL'),
            ),
            DropdownButtonFormField<GlucoseContext>(
              initialValue: contextValue,
              items: GlucoseContext.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => contextValue = v ?? contextValue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v <= 0 || v > 1000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('مقدار قند معتبر نیست.')),
                );
                return;
              }
              Navigator.pop(
                context,
                GlucoseReading(
                  time: DateTime.now(),
                  mgDl: v,
                  context: contextValue,
                ),
              );
            },
            child: const Text('ثبت'),
          ),
        ],
      );
}

class MealDialog extends StatefulWidget {
  const MealDialog({super.key});
  @override
  State<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<MealDialog> {
  var kind = 'صبحانه';
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('ثبت غذا'),
        content: DropdownButtonFormField<String>(
          initialValue: kind,
          items: const [
            DropdownMenuItem(value: 'صبحانه', child: Text('صبحانه')),
            DropdownMenuItem(value: 'ناهار', child: Text('ناهار')),
            DropdownMenuItem(value: 'شام', child: Text('شام')),
            DropdownMenuItem(value: 'میان‌وعده', child: Text('میان‌وعده')),
          ],
          onChanged: (v) => setState(() => kind = v ?? kind),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              MealEntry(time: DateTime.now(), kind: kind),
            ),
            child: const Text('ثبت'),
          ),
        ],
      );
}

class ActivityDialog extends StatefulWidget {
  const ActivityDialog({super.key});
  @override
  State<ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<ActivityDialog> {
  final minutes = TextEditingController(text: '30');
  var intensity = 'medium';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('ثبت فعالیت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدت (دقیقه)'),
            ),
            DropdownButtonFormField<String>(
              initialValue: intensity,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('کم')),
                DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                DropdownMenuItem(value: 'high', child: Text('زیاد')),
              ],
              onChanged: (v) => setState(() => intensity = v ?? intensity),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(minutes.text.trim());
              if (v == null || v <= 0 || v > 600) return;
              Navigator.pop(
                context,
                ActivityEntry(
                  time: DateTime.now(),
                  durationMinutes: v,
                  intensity: intensity,
                ),
              );
            },
            child: const Text('ثبت'),
          ),
        ],
      );
}

class HypoDialog extends StatefulWidget {
  const HypoDialog({super.key});
  @override
  State<HypoDialog> createState() => _HypoDialogState();
}

class _HypoDialogState extends State<HypoDialog> {
  final glucose = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('ثبت افت قند'),
        content: TextField(
          controller: glucose,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'قند اندازه‌گیری‌شده (اختیاری)',
            suffixText: 'mg/dL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              HypoglycemiaEvent(
                time: DateTime.now(),
                measuredMgDl: double.tryParse(glucose.text.trim()),
              ),
            ),
            child: const Text('ثبت'),
          ),
        ],
      );
}
