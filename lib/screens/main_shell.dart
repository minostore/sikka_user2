import 'package:flutter/material.dart';
import '../services/local_notify.dart';
import '../services/nav_memory.dart';
import '../services/push_service.dart';
import '../services/ride_service.dart';
import 'ride_flow_screen.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'wallet_screen.dart';
import 'account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = NavMemory.tab(4); // آخر تبويب كان فيه المستخدم قبل إغلاق التطبيق

  @override
  void initState() {
    super.initState();
    LocalNotify.startListening();
    PushService.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreActiveRide());
  }

  /// إن كانت هناك رحلة جارية عند إعادة فتح التطبيق نعيد المستخدم إلى شاشتها مباشرة.
  Future<void> _restoreActiveRide() async {
    try {
      final id = await RideService.activeRideId();
      if (id == null || id.isEmpty || !mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideFlowScreen(rideId: id)));
    } catch (_) {}
  }

  @override
  void dispose() {
    LocalNotify.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: const [
          HomeScreen(),
          TripsScreen(),
          WalletScreen(),
          AccountScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: _i,
          onDestinationSelected: (v) {
            NavMemory.saveTab(v);
            setState(() => _i = v);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.history), label: 'رحلاتي'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      );
}
