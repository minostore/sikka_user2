import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'welcome_onboarding.dart';

/// بوابة تطبيق الراكب فقط. لا تعرض واجهات السائق داخل تطبيق المستخدم.
class SplashGate extends StatelessWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      return SikkaWelcome(homeBuilder: () => const SplashGate());
    }

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/${current.uid}').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: ErrorView('تعذر تحميل بيانات الحساب. تحقق من اتصال الإنترنت وصلاحيات قاعدة البيانات.')));
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: LoadingView()));
        final data = asMap(snapshot.data!.snapshot.value);
        final role = (data['role'] ?? '').toString();
        final status = (data['status'] ?? 'active').toString();

        if (role == 'driver') {
          return _WrongAppScreen(onSignOut: () async {
            await AuthService.signOut();
          });
        }
        if (role != 'rider') {
          return _WrongAppScreen(onSignOut: () async {
            await AuthService.signOut();
          });
        }
        if (status == 'suspended') {
          return _SuspendedScreen(onSignOut: () async {
            await AuthService.signOut();
          });
        }
        return const MainShell();
      },
    );
  }
}

class _WrongAppScreen extends StatelessWidget {
  final Future<void> Function() onSignOut;
  const _WrongAppScreen({required this.onSignOut});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.drive_eta_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('هذا حساب سائق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('الحساب ده مخصص لتطبيق سِكّة للسائقين. سجّل الخروج وافتح تطبيق السائق.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () async { await onSignOut(); }, child: const Text('تسجيل الخروج')),
            ]),
          ),
        ),
      );
}

class _SuspendedScreen extends StatelessWidget {
  final Future<void> Function() onSignOut;
  const _SuspendedScreen({required this.onSignOut});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.block_rounded, size: 60, color: AppColors.red),
              const SizedBox(height: 12),
              const Text('تم إيقاف الحساب. تواصل مع الدعم.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () async { await onSignOut(); }, child: const Text('تسجيل الخروج')),
            ]),
          ),
        ),
      );
}
