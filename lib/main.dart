import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'widgets/update_gate.dart';
import 'firebase_options.dart';
import 'screens/splash_gate.dart';
import 'services/local_notify.dart';
import 'services/nav_memory.dart';
import 'services/zone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }
  if (initError == null) ZoneService.start();
  await LocalNotify.init();
  await NavMemory.init();
  runApp(SikkaUserApp(initError: initError));
}

class SikkaUserApp extends StatelessWidget {
  final Object? initError;
  const SikkaUserApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sikka User',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => UpdateGate(role: 'rider', child: child ?? const SizedBox.shrink()),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: initError != null
            ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تهيئة Firebase:\n$initError', textAlign: TextAlign.center))))
            : const SplashGate(),
      );
}
