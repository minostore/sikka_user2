import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'daily_trips_screen.dart';
import 'edit_profile_screen.dart';
import 'legal_screen.dart';
import 'place_search_screen.dart';
import 'splash_gate.dart';
import 'support_home_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _setPlace(BuildContext context, String uid, String key) async {
    final p = await Navigator.push<Place>(
        context, MaterialPageRoute(builder: (_) => PlaceSearchScreen(title: key == 'home' ? 'عنوان المنزل' : 'عنوان العمل')));
    if (p != null) {
      await FirebaseDatabase.instance.ref('users/$uid/places/$key').set(p.toMap());
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$uid').onValue,
        builder: (c, s) {
          if (!s.hasData) return const LoadingView();
          final m = asMap(s.data!.snapshot.value);
          final name = (m['name'] ?? '').toString();
          final photo = (m['photoUrl'] ?? '').toString();
          final places = asMap(m['places']);
          Widget item(IconData i, String t, VoidCallback f, {String? sub}) => ListTile(
              leading: Icon(i, color: AppColors.primary), title: Text(t), subtitle: sub == null ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.chevron_left), onTap: f);
          return ListView(children: [
            // الصورة والاسم أعلى اليمين
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                  child: photo.startsWith('http') ? null : const Icon(Icons.person, size: 34, color: AppColors.navy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('+${m['phone'] ?? ''}', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.grey)),
                  ]),
                ),
              ]),
            ),
            const Divider(),
            item(Icons.edit, 'تعديل الملف الشخصي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(data: m)))),
            item(Icons.home, 'عنوان المنزل', () => _setPlace(context, uid, 'home'), sub: asMap(places['home'])['address']?.toString()),
            item(Icons.work, 'عنوان العمل', () => _setPlace(context, uid, 'work'), sub: asMap(places['work'])['address']?.toString()),
            item(Icons.event_repeat, 'الرحلات اليومية', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyTripsScreen()))),
            item(Icons.support_agent, 'المساعدة والدعم', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportHomeScreen(role: 'rider')))),
            item(Icons.description_outlined, 'الشروط والخصوصية', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen()))),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.red)),
              onTap: () async {
                if (!await confirmDialog(context, 'تسجيل الخروج', 'هل تريد تسجيل الخروج؟')) return;
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
                }
              },
            ),
          ]);
        },
      ),
    );
  }
}
