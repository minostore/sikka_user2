import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikka_user/screens/welcome_onboarding.dart';

void main() {
  testWidgets('shows four onboarding steps and continues to login', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SikkaWelcome(homeBuilder: () => const Scaffold(body: Text('home')))));
    await tester.pumpAndSettle();

    expect(find.text('ابدأ رحلتك مع سِكّة'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('وأكمل رحلتك بأمان'), findsOneWidget);
    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
  });

  testWidgets('skip opens login directly', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SikkaWelcome(homeBuilder: () => const Scaffold(body: Text('home')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
  });
}
