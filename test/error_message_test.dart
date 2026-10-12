import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikka_user/core/utils.dart';

void main() {
  test('converts Firebase permission errors to actionable Arabic text', () {
    final text = errorMessage(
      FirebaseException(plugin: 'database', code: 'permission-denied'),
    );
    expect(text, contains('قواعد Firebase'));
    expect(text, contains('database/permission-denied'));
  });

  test('preserves the reason from ordinary exceptions', () {
    expect(errorMessage(Exception('الاتصال مرفوض')), 'الاتصال مرفوض');
  });
}
