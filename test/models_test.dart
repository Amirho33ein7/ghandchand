import 'package:flutter_test/flutter_test.dart';
import 'package:lowguard/models.dart';

void main() {
  test('profile map round trip', () {
    const p = UserProfile(
      name: 'Test',
      fastingGlucose: 95,
      nonFastingGlucose: 125,
      sleepHour: 23,
      sleepMinute: 30,
      wakeHour: 7,
      wakeMinute: 30,
      historyOfHypo: true,
      nighttimeHypo: true,
    );
    final copy = UserProfile.fromMap(p.toMap());
    expect(copy.name, p.name);
    expect(copy.fastingGlucose, 95);
    expect(copy.nighttimeHypo, isTrue);
  });
}
