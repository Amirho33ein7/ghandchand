import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'lowguard.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE user_profile (id INTEGER PRIMARY KEY, name TEXT NOT NULL, fasting_glucose REAL, non_fasting_glucose REAL, sleep_hour INTEGER NOT NULL, sleep_minute INTEGER NOT NULL, wake_hour INTEGER NOT NULL, wake_minute INTEGER NOT NULL, glucose_unit TEXT NOT NULL, diabetes_type TEXT, history_of_hypo INTEGER NOT NULL DEFAULT 0, nighttime_hypo INTEGER NOT NULL DEFAULT 0, uses_insulin INTEGER NOT NULL DEFAULT 0, uses_glucose_lowering_medication INTEGER NOT NULL DEFAULT 0, meals_per_day INTEGER NOT NULL DEFAULT 3)');
        await db.execute('CREATE TABLE glucose_readings (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, mg_dl REAL NOT NULL, context TEXT NOT NULL)');
        await db.execute('CREATE TABLE meals (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, kind TEXT NOT NULL)');
        await db.execute('CREATE TABLE activities (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, duration_minutes INTEGER NOT NULL, intensity TEXT NOT NULL)');
        await db.execute('CREATE TABLE hypo_events (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, measured_mg_dl REAL, symptoms TEXT)');
        await db.execute('CREATE INDEX idx_glucose_time ON glucose_readings(time)');
        await db.execute('CREATE INDEX idx_meals_time ON meals(time)');
        await db.execute('CREATE INDEX idx_activities_time ON activities(time)');
        await db.execute('CREATE INDEX idx_hypo_time ON hypo_events(time)');
      },
    );
    return _db!;
  }

  Future<UserProfile?> getProfile() async {
    final rows = await (await database).query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile p) async {
    await (await database).insert(
      'user_profile',
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addGlucose(GlucoseReading r) async =>
      (await database).insert('glucose_readings', r.toMap());

  Future<List<GlucoseReading>> glucose() async =>
      (await database).query('glucose_readings', orderBy: 'time DESC').then(
            (rows) => rows.map(GlucoseReading.fromMap).toList(),
          );

  Future<void> addMeal(MealEntry m) async =>
      (await database).insert('meals', m.toMap());

  Future<List<MealEntry>> meals() async =>
      (await database).query('meals', orderBy: 'time DESC').then(
            (rows) => rows.map(MealEntry.fromMap).toList(),
          );

  Future<void> addActivity(ActivityEntry a) async =>
      (await database).insert('activities', a.toMap());

  Future<List<ActivityEntry>> activities() async =>
      (await database).query('activities', orderBy: 'time DESC').then(
            (rows) => rows.map(ActivityEntry.fromMap).toList(),
          );

  Future<void> addHypo(HypoglycemiaEvent e) async =>
      (await database).insert('hypo_events', e.toMap());

  Future<List<HypoglycemiaEvent>> hypos() async =>
      (await database).query('hypo_events', orderBy: 'time DESC').then(
            (rows) => rows.map(HypoglycemiaEvent.fromMap).toList(),
          );
}
