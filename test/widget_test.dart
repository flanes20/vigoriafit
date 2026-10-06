import 'package:flutter_test/flutter_test.dart';

import 'package:vigoriafit/models/profile.dart';

void main() {
  test('El perfil calcula IMC y proteína según los datos', () {
    final p = Profile(weightKg: 80, heightCm: 180, goal: Goal.gainMuscle);
    expect(p.bmi, closeTo(24.7, 0.2));
    expect(p.proteinGrams, 160); // 80 kg * 2.0 g/kg para ganar masa
  });
}
