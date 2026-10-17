import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/ride_service.dart';
import '../widgets/common.dart';

const int _maxContacts = 5;

/// مركز السلامة للعميل: جهات اتصال موثوقة، مشاركة الرحلة، طلب الشرطة، وبلاغ طوارئ للدعم.
class SafetyCenterScreen extends StatefulWidget {
  /// رقم الرحلة الجارية إن وُجدت (اختياري؛ إن لم يُمرَّر نبحث عن الرحلة النشطة).
  final String? rideId;
  const SafetyCenterScreen({super.key, this.rideId});
  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  DatabaseReference get _contactsRef => FirebaseDatabase.instance.ref('users/$_uid/trustedContacts');
  bool _busy = false;
  List<Map<String, dynamic>> _extraTools = [];

  @override
  void initState() {
    super.initState();
    _loadExtraTools();
  }

  /// أدوات سلامة إضافية تضيفها الإدارة من لوحة التحكم ← settings/safetyTools
  Future<void> _loadExtraTools() async {
    try {
      final raw = (await FirebaseDatabase.instance.ref('settings/safetyTools').get()).value;
      final list = <Map<String, dynamic>>[];
      final vals = raw is Map ? raw.values.toList() : raw is List ? raw : const [];
      for (final v in vals) {
        if (v is Map && v['active'] != false && (v['title'] ?? '').toString().trim().isNotEmpty) list.add(Map<String, dynamic>.from(v));
      }
      list.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      if (mounted) setState(() => _extraTools = list);
    } catch (_) {}
  }

  Future<void> _runExtraTool(Map<String, dynamic> t) async {
    final phone = (t['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) {
      final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!ok && mounted) showSnack(context, 'تعذر فتح تطبيق الاتصال', error: true);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((t['title'] ?? '').toString()),
        content: Text((t['description'] ?? '').toString()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))],
      ),
    );
  }

  Future<Position?> _position() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) {
      return null;
    }
  }

  String _mapLink(Position? p) =>
      p == null ? '' : '\nموقعي: https://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=17/${p.latitude}/${p.longitude}';

  Future<Ride?> _currentRide() async {
    final id = widget.rideId ?? await RideService.activeRideId();
    if (id == null || id.isEmpty) return null;
    final s = await FirebaseDatabase.instance.ref('rides/$id').get();
    if (s.value == null) return null;
    return Ride.fromMap(id, asMap(s.value));
  }

  // ───────── جهات الاتصال الموثوقة ─────────
  Future<void> _addContact(int current) async {
    if (current >= _maxContacts) return showSnack(context, 'الحد الأقصى $_maxContacts جهات اتصال', error: true);
    final name = TextEditingController(), phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة جهة اتصال موثوقة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 8),
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الموبايل')),
          const SizedBox(height: 8),
          const Text('ستتمكن من مشاركة رحلاتك معها بسرعة. لن نرسل لها أي شيء دون ضغطك على زر المشاركة.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final n = name.text.trim(), p = phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (ok != true) return;
    if (n.isEmpty || p.length < 8) return showSnack(context, 'أدخل اسمًا ورقمًا صحيحًا', error: true);
    try {
      await _contactsRef.push().set({'name': n, 'phone': p, 'createdAt': ServerValue.timestamp});
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر حفظ جهة الاتصال'), error: true);
    }
  }

  Future<void> _removeContact(String id) async {
    if (!await confirmDialog(context, 'حذف جهة الاتصال', 'هل تريد حذف هذه الجهة؟')) return;
    await _contactsRef.child(id).remove().catchError((_) {});
  }

  // ───────── مشاركة الرحلة ─────────
  Future<void> _shareTrip(List<Map<String, dynamic>> contacts) async {
    setState(() => _busy = true);
    try {
      final ride = await _currentRide();
      final pos = await _position();
      if (ride == null) {
        if (mounted) showSnack(context, 'لا توجد رحلة جارية لمشاركتها', error: true);
        return;
      }
      final text = 'أنا الآن في رحلة مع ${AppConfig.appName} إلى ${ride.dest.address}\n'
          'السائق: ${ride.driverName ?? ''} - ${ride.vehicle ?? ''} - لوحة: ${ride.plate ?? ''}'
          '${_mapLink(pos)}';
      if (contacts.isNotEmpty && mounted) {
        final viaSms = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('مشاركة الرحلة'),
            content: const Text('اختر طريقة المشاركة'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('اختيار تطبيق')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رسالة للجهات الموثوقة')),
            ],
          ),
        );
        if (viaSms == true) {
          final nums = contacts.map((c) => c['phone']).join(',');
          final ok = await launchUrl(Uri(scheme: 'sms', path: nums, queryParameters: {'body': text}));
          if (!ok && mounted) showSnack(context, 'تعذر فتح تطبيق الرسائل', error: true);
          return;
        }
      }
      await SharePlus.instance.share(ShareParams(text: text));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── طلب الشرطة ─────────
  Future<void> _callPolice() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب الشرطة'),
        content: Text('سيتم فتح تطبيق الاتصال على الرقم ${AppConfig.emergencyNumber}. لن يرسل هذا الزر موقعك تلقائيًا؛ استخدم «بلاغ طوارئ للدعم» لإرسال موقعك لفريقنا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اتصال')),
        ],
      ),
    );
    if (go != true) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: AppConfig.emergencyNumber));
    if (!ok && mounted) showSnack(context, 'تعذر فتح تطبيق الاتصال', error: true);
  }

  // ───────── بلاغ طوارئ للدعم (SOS) ─────────
  Future<void> _sendSos() async {
    if (!await confirmDialog(context, 'بلاغ طوارئ للدعم', 'سيتم إرسال موقعك وبيانات رحلتك الحالية لفريق الدعم فورًا. هل تريد المتابعة؟')) return;
    setState(() => _busy = true);
    try {
      final ride = await _currentRide();
      final pos = await _position();
      final db = FirebaseDatabase.instance.ref();
      final id = db.child('safetyAlerts').push().key!;
      await db.update({
        'safetyAlerts/$id': {
          'uid': _uid,
          'role': 'rider',
          'type': 'sos',
          'status': 'open',
          'rideId': ride?.id,
          'driverId': ride?.driverId,
          'lat': pos?.latitude,
          'lng': pos?.longitude,
          'createdAt': ServerValue.timestamp,
        },
        if (ride != null) 'rides/${ride.id}/sosAlertId': id,
      });
      if (mounted) showSnack(context, 'تم إرسال بلاغك لفريق الدعم. إذا كنت في خطر اتصل بالشرطة فورًا.');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر إرسال البلاغ، اتصل بالشرطة مباشرة'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tool(IconData icon, Color color, String title, String sub, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12.5))),
                ]),
              ),
              const Icon(Icons.chevron_left),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مركز السلامة')),
        body: StreamBuilder<DatabaseEvent>(
          stream: _contactsRef.onValue,
          builder: (c, s) {
            final raw = asMap(s.data?.snapshot.value);
            final contacts = [
              for (final e in raw.entries) {...asMap(e.value), 'id': e.key}
            ];
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('أدوات السلامة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _tool(Icons.share_location, const Color(0xFF1E6BFF), 'مشاركة الرحلة', 'أرسل بيانات رحلتك وموقعك لمن تثق بهم', () => _shareTrip(contacts)),
              _tool(Icons.local_police, AppColors.red, 'طلب الشرطة', 'اتصال سريع برقم ${AppConfig.emergencyNumber}', _callPolice),
              _tool(Icons.sos, const Color(0xFFD32F2F), 'بلاغ طوارئ للدعم', 'يرسل موقعك ورقم رحلتك لفريق الدعم فورًا', _sendSos),
              for (final t in _extraTools)
                _tool(Icons.health_and_safety_outlined, const Color(0xFF00897B), (t['title'] ?? '').toString(), (t['description'] ?? '').toString(), () => _runExtraTool(t)),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Text('جهات اتصال موثوقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                TextButton.icon(onPressed: () => _addContact(contacts.length), icon: const Icon(Icons.add), label: const Text('إضافة')),
              ]),
              if (contacts.isEmpty)
                const InfoCard(child: Text('لم تضف جهات اتصال بعد. أضف حتى 5 أشخاص لمشاركة رحلاتك معهم بسرعة.', style: TextStyle(color: Colors.grey)))
              else
                InfoCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final ct in contacts)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text('${ct['name']}'),
                        subtitle: Text('${ct['phone']}', textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: () => _removeContact(ct['id'].toString())),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      );
}
