import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/markers.dart';
import 'notifications_screen.dart';
import 'support_tickets_screen.dart';
import 'ride_flow_screen.dart';
import 'select_route_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  final _db = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  LatLng? _me;
  bool _loading = true;
  List<LatLng> _drivers = [];
  String? _activeRide;
  Map<String, Place> _saved = {};
  String _name = '';
  final _subs = <StreamSubscription>[];
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _locate();
    _subs.add(
      _db.child('onlineDrivers').onValue.listen(_onDrivers, onError: (_) {}),
    );
    _subs.add(
      _db.child('users/$_uid/activeRide').onValue.listen((e) {
        if (mounted) setState(() => _activeRide = e.snapshot.value?.toString());
      }, onError: (_) {}),
    );
    _subs.add(
      _db.child('users/$_uid').onValue.listen((e) {
        final m = asMap(e.snapshot.value);
        final places = asMap(m['places']);
        if (mounted)
          setState(() {
            _name = (m['name'] ?? '').toString();
            _saved = places.map((k, v) => MapEntry(k, Place.fromMap(asMap(v))));
          });
      }, onError: (_) {}),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _locationSub?.cancel();
    super.dispose();
  }

  void _onDrivers(DatabaseEvent e) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <LatLng>[];
    asMap(e.snapshot.value).forEach((_, v) {
      final m = asMap(v);
      final upd = (m['updatedAt'] as num?)?.toInt() ?? 0;
      if (now - upd > 3 * 60 * 1000) return;
      final p = LatLng(numD(m['lat']), numD(m['lng']));
      if (_me == null || haversineKm(_me!, p) <= AppConfig.nearbyRadiusKm)
        out.add(p);
    });
    if (mounted) setState(() => _drivers = out);
  }

  Future<void> _locate({bool move = false}) async {
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() => _me = p);
      if (move) _map.move(p, 15);
      _locationSub ??= LocationService.stream(distanceFilter: 10)
          .listen((position) {
            if (!mounted) return;
            final next = LatLng(position.latitude, position.longitude);
            setState(() => _me = next);
          }, onError: (_) {});
    } catch (e) {
      showLocationError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start({Place? dest}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SelectRouteScreen(initialDest: dest, saved: _saved),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: InfoCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'مرحباً${_name.isEmpty ? '' : '، $_name'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'خدمة العملاء',
                    color: AppColors.ink,
                    icon: const Icon(Icons.support_agent),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportTicketsScreen(role: 'rider'),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'الإشعارات',
                    color: AppColors.ink,
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppMap(
                  controller: _map,
                  center: _me ?? AppConfig.defaultCenter,
                  markers: [
                    ..._drivers.map(
                      (d) => Markers.car(d, color: AppColors.primary),
                    ),
                    if (_me != null) Markers.me(_me!),
                  ],
                  onRecenter: () => _locate(move: true),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: InfoCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeRide != null) ...[
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'لديك رحلة جارية',
                              style: TextStyle(color: AppColors.ink),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RideFlowScreen(rideId: _activeRide!),
                              ),
                            ),
                            child: const Text('متابعة'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  InkWell(
                    onTap: _activeRide != null ? null : () => _start(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: Color(0x1AFFCC00),
                            child: Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'إلى أين تريد الذهاب؟',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'اختر وجهتك وسنوصلك بأقرب سائق',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFA9B4C2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Color(0xFFA9B4C2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_saved.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in _saved.entries)
                          ActionChip(
                            avatar: Icon(
                              e.key == 'home' ? Icons.home : Icons.work,
                              size: 18,
                            ),
                            label: Text(e.key == 'home' ? 'المنزل' : 'العمل'),
                            onPressed: _activeRide != null
                                ? null
                                : () => _start(dest: e.value),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _drivers.isEmpty
                        ? 'لا يوجد سائقون قريبون حالياً'
                        : 'يوجد ${_drivers.length} سائق قريب منك',
                    style: const TextStyle(
                      color: Color(0xFFA9B4C2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
