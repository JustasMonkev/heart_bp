import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/blood_pressure_tips.dart';

void main() {
  test('tipForSeed wraps around the available tips', () {
    final firstTip = BloodPressureTips.tipForSeed(0);
    final wrappedTip = BloodPressureTips.tipForSeed(
      BloodPressureTips.items.length,
    );

    expect(wrappedTip.title, firstTip.title);
    expect(wrappedTip.message, firstTip.message);
  });

  test('tipForSeed always returns a non-empty tip', () {
    for (var seed = 0; seed < BloodPressureTips.items.length * 3; seed++) {
      final tip = BloodPressureTips.tipForSeed(seed);

      expect(tip.title.trim(), isNotEmpty);
      expect(tip.message.trim(), isNotEmpty);
    }
  });
}
