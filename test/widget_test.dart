import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikka_user/screens/welcome_onboarding.dart';

void main() {
  testWidgets('onboarding shows next on top, then start + login on last slide', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SikkaWelcome(homeBuilder: () => const Scaffold(body: Text('home')))));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('التالي'), findsNothing);
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
  });
}
