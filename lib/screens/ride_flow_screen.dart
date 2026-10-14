import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/ride_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/back_guard.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';
import 'ride_chat_screen.dart';
import 'ticket_chat_screen.dart';

/// يتابع حالة الرحلة لحظياً ويعرض: العروض ← التتبع ← التقييم
class RideFlowScreen extends StatelessWidget {
  final String rideId;
  const RideFlowScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: RideService.db.child('rides/$rideId').onValue,
        builder: (c, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(title: const Text('رحلتك')), body: const ErrorView('تعذر تحميل بيانات الرحلة.'));
          if (!s.hasData) return Scaffold(appBar: AppBar(title: const Text('رحلتك')), body: const LoadingView());
          if (!s.data!.snapshot.exists) return Scaffold(appBar: AppBar(title: const Text('رحلتك')), body: const EmptyView('الرحلة غير موجودة'));
          final ride = Ride.fromMap(rideId, asMap(s.data!.snapshot.value));
          switch (ride.status) {
            case 'requested':
              return Scaffold(appBar: AppBar(title: const Text('جاري البحث عن سائق')), body: _OffersView(ride: ride));
            case 'completed':
              return PopScope(
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) RideService.clearActive().catchError((_) {});
                },
                child: Scaffold(appBar: AppBar(title: const Text('رحلتك')), body: _RatingView(ride: ride)),
              );
            case 'cancelled':
              return Scaffold(appBar: AppBar(title: const Text('رحلتك')), body: _CancelledView(ride: ride));
            default:
              // رحلة مؤكدة: الرجوع لا يعيد لصفحة سابقة، والضغطة الثانية تغلق التطبيق
              return DoubleBackExit(
                child: Scaffold(appBar: AppBar(title: const Text('رحلتك'), automaticallyImplyLeading: false), body: _TrackingView(ride: ride)),
              );
          }
        },
      );
}

Future<void> _openCall(BuildContext c, String phone) async {
  if (phone.isEmpty) return showSnack(c, 'رقم الهاتف غير متاح', error: true);
  final ok = await launchUrl(Uri(scheme: 'tel', path: '+$phone'));
  if (!ok && c.mounted) showSnack(c, 'تعذر فتح تطبيق الاتصال', error: true);
}

/// الطوارئ: يفتح الاتصال برقم النجدة. التطبيق لا يرسل أي استغاثة تلقائية.
Future<void> _emergency(BuildContext c) async {
  final go = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: const Text('مكالمة طوارئ'),
      content: Text('سيتم فتح تطبيق الاتصال على الرقم ${AppConfig.emergencyNumber}. لن يرسل التطبيق موقعك أو أي بلاغ تلقائياً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اتصال')),
      ],
    ),
  );
  if (go != true || !c.mounted) return;
  final ok = await launchUrl(Uri(scheme: 'tel', path: AppConfig.emergencyNumber));
  if (!ok && c.mounted) showSnack(c, 'تعذر فتح تطبيق الاتصال', error: true);
}

// ───────────────────────── العروض ─────────────────────────
class _OffersView extends StatefulWidget {
  final Ride ride;
  const _OffersView({required this.ride});
  @override
  State<_OffersView> createState() => _OffersViewState();
}

class _OffersViewState extends State<_OffersView> {
  String _sort = 'price';
  bool _busy = false;
  int _serverOffsetMs = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;

  @override
  void initState() {
    super.initState();
    _offsetSub = RideService.db.child('.info/serverTimeOffset').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num && mounted) setState(() => _serverOffsetMs = value.toInt());
    });
  }

  @override
  void dispose() {
    _offsetSub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'إلغاء الطلب', 'هل تريد إلغاء طلب الرحلة؟',
        yes: 'نعم، إلغاء')) {
      return;
    }
    try {
      await RideService.cancel(widget.ride.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر إلغاء الطلب'), error: true);
    }
  }

  Future<void> _accept(Offer o) async {
    if (!await confirmDialog(context, 'تأكيد السائق',
        'اختيار ${o.name} بسعر ${money(o.price)}؟')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await RideService.acceptOffer(widget.ride.id, o);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر قبول العرض'), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return StreamBuilder<DatabaseEvent>(
      stream: RideService.db.child('rides/${r.id}/offers').onValue,
      builder: (c, s) {
        final offers = <Offer>[];
        if (s.hasData && s.data!.snapshot.exists) {
          asMap(s.data!.snapshot.value).forEach((k, v) => offers.add(Offer.fromMap(k, asMap(v))));
        }
        offers.sort((a, b) {
          switch (_sort) {
            case 'eta':
              return a.etaMin.compareTo(b.etaMin);
            case 'rating':
              return b.rating.compareTo(a.rating);
            default:
              return a.price.compareTo(b.price);
          }
        });
        final serverNow = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
        final expired = r.createdAt != null && serverNow - r.createdAt! > const Duration(seconds: 60).inMilliseconds;
        final searching = offers.isEmpty;
        return Column(children: [
          // خريطة معاينة: نقطة الانطلاق ونقطة الوصول وخط الطريق
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(height: searching ? 210 : 150, child: _RoutePreview(ride: r)),
          ),
          Expanded(
            child: searching
                ? _SearchingPanel(expired: expired)
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Row(children: [
                        const Text('الفرز: '),
                        for (final e in const {'price': 'السعر الأقل', 'eta': 'الأقرب وصولاً', 'rating': 'الأعلى تقييماً'}.entries)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ChoiceChip(
                              label: Text(e.value, style: const TextStyle(fontSize: 12)),
                              selected: _sort == e.key,
                              onSelected: (_) => setState(() => _sort = e.key),
                            ),
                          ),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [for (final o in offers) _offerCard(o)])),
                  ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppButton('إلغاء الطلب', onPressed: _cancel),
                if (searching && !expired)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('سيتم إشعارك فور قبول الكابتن', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _offerCard(Offer o) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundImage: o.photoUrl.startsWith('http') ? NetworkImage(o.photoUrl) : null,
                child: o.photoUrl.startsWith('http') ? null : const Icon(Icons.person),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('★ ${o.rating.toStringAsFixed(1)} • ${o.trips} مشوار', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              Text(money(o.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(height: 6),
            Text('${o.vehicle} • يصل خلال ${o.etaMin} دقائق'),
            if (o.note.isNotEmpty) Text(o.note, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              onPressed: _busy ? null : () => _accept(o),
              child: const Text('اختيار'),
            ),
          ]),
        ),
      );
}

/// معاينة الرحلة: نقطتا الانطلاق والوصول وخط الطريق بينهما.
class _RoutePreview extends StatefulWidget {
  final Ride ride;
  const _RoutePreview({required this.ride});
  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  final _map = MapController();
  RouteInfo? _route;

  @override
  void initState() {
    super.initState();
    RoutingService.route(widget.ride.pickup.point, widget.ride.dest.point).then((info) {
      if (!mounted) return;
      setState(() => _route = info);
      fitPoints(_map, info.points);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: IgnorePointer(
        child: AppMap(
          controller: _map,
          center: r.pickup.point,
          zoom: 13,
          showControls: false,
          polylines: [if (_route != null) Polyline(points: _route!.points, strokeWidth: 5, color: AppColors.primary)],
          markers: [Markers.pin(r.pickup.point, AppColors.green), Markers.pin(r.dest.point, AppColors.red)],
        ),
      ),
    );
  }
}

/// لوحة البحث: رادار متحرك + عنوان + مراحل الطلب (إرسال ← بحث ← تأكيد).
class _SearchingPanel extends StatefulWidget {
  final bool expired;
  const _SearchingPanel({required this.expired});
  @override
  State<_SearchingPanel> createState() => _SearchingPanelState();
}

class _SearchingPanelState extends State<_SearchingPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _step(String label, {required bool done, required bool active}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.primary : Colors.transparent,
            border: Border.all(color: done || active ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 18, color: AppColors.navy)
              : active
                  ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)))
                  : null,
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.normal, color: done || active ? Colors.white : Colors.grey)),
      ]);

  Widget _line(bool on) => Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 22), child: Container(height: 2, color: on ? AppColors.primary : AppColors.border)));

  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 170,
          height: 170,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              if (!widget.expired)
                for (var i = 0; i < 3; i++)
                  Builder(builder: (_) {
                    final t = (_c.value + i / 3) % 1;
                    return Opacity(
                      opacity: (1 - t) * 0.7,
                      child: Container(
                        width: 70 + 100 * t,
                        height: 70 + 100 * t,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
                      ),
                    );
                  }),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card, border: Border.all(color: AppColors.primary, width: 2.5)),
                child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 38),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.expired ? 'لم يصل أي عرض بعد' : 'جاري البحث عن سائق قريب منك', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(widget.expired ? 'انتهت مهلة الطلب. ألغِ الطلب وأعد المحاولة.' : 'نبحث عن أفضل كابتن لرحلتك، يرجى الانتظار',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _step('إرسال الطلب', done: true, active: false),
            _line(true),
            _step('البحث عن كابتن', done: false, active: true),
            _line(false),
            _step('تأكيد الرحلة', done: false, active: false),
          ]),
        ),
      ]);
}

// ───────────────────────── التتبع ─────────────────────────
class _TrackingView extends StatefulWidget {
  final Ride ride;
  const _TrackingView({required this.ride});
  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> {
  final _map = MapController();
  StreamSubscription? _sub;
  LatLng? _driver;
  double _heading = 0;
  int? _updatedAt;
  RouteInfo? _route;
  DateTime _lastRoute = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tick;

  Ride get r => widget.ride;
  LatLng get _target => r.status == 'started' ? r.dest.point : r.pickup.point;

  @override
  void initState() {
    super.initState();
    _sub = RideService.db.child('driverLocations/${r.driverId}').onValue.listen((e) {
      if (!e.snapshot.exists) return;
      final m = asMap(e.snapshot.value);
      final p = LatLng(numD(m['lat']), numD(m['lng']));
      setState(() {
        _driver = p;
        _heading = numD(m['heading']);
        _updatedAt = (m['updatedAt'] as num?)?.toInt();
      });
      _maybeRoute(p);
    }, onError: (_) {});
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _maybeRoute(LatLng p) async {
    if (DateTime.now().difference(_lastRoute).inSeconds < 25) return;
    _lastRoute = DateTime.now();
    final info = await RoutingService.route(p, _target);
    if (!mounted) return;
    setState(() => _route = info);
    if (_route != null && _route!.points.length > 1) fitPoints(_map, [p, _target]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'إلغاء الرحلة', 'هل أنت متأكد من إلغاء الرحلة؟',
        yes: 'نعم، إلغاء')) {
      return;
    }
    try {
      await RideService.cancel(r.id, driverId: r.driverId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر الإلغاء', error: true);
    }
  }

  Future<void> _report() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن مشكلة'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'اشرح المشكلة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        final ticketId = await RideService.createTicket('بلاغ عن رحلة', ctrl.text.trim(), rideId: r.id);
        if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: ticketId, role: 'user')));
      } catch (_) {
        if (mounted) showSnack(context, 'تعذر إرسال البلاغ', error: true);
      }
    }
  }

  void _share() {
    final p = _driver;
    final link = p == null
        ? ''
        : '\nhttps://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=16/${p.latitude}/${p.longitude}';
    SharePlus.instance.share(ShareParams(
        text: 'أنا في رحلة مع مشوار إلى ${r.dest.address}\nالسائق: ${r.driverName ?? ''} - ${r.vehicle ?? ''}$link'));
  }

  @override
  Widget build(BuildContext context) {
    final stale = _updatedAt != null &&
        DateTime.now().millisecondsSinceEpoch - _updatedAt! > 60 * 1000;
    return Column(children: [
      Expanded(
        child: AppMap(
          controller: _map,
          center: _driver ?? r.pickup.point,
          zoom: 14,
          polylines: [
            if (_route != null)
              Polyline(points: _route!.points, strokeWidth: 5, color: AppColors.primary),
          ],
          markers: [
            Markers.pin(r.pickup.point, AppColors.green),
            Markers.pin(r.dest.point, AppColors.red),
            if (_driver != null) Markers.car(_driver!, heading: _heading),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black26)],
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill(statusLabel(r.status), statusColor(r.status)),
              const Spacer(),
              if (_route != null) Text('الوصول المتوقع: ${_route!.durationMin.round()} دقيقة'),
            ]),
            const SizedBox(height: 4),
            Text(
              _driver == null
                  ? 'بانتظار موقع السائق...'
                  : stale
                      ? 'انقطع تحديث موقع السائق (${timeAgo(_updatedAt)})'
                      : 'آخر تحديث للموقع: ${timeAgo(_updatedAt)}',
              style: TextStyle(fontSize: 12, color: stale ? AppColors.red : Colors.grey),
            ),
            const Divider(),
            Row(children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.driverName ?? 'السائق', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${r.vehicle ?? ''}  ★ ${r.driverRating.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              Text(money(r.finalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _openCall(context, r.driverPhone ?? ''), icon: const Icon(Icons.call), label: const Text('اتصال'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('مشاركة'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _report, icon: const Icon(Icons.report_problem_outlined), label: const Text('بلاغ'))),
            ]),
            if (r.status == 'accepted' || r.status == 'arrived' || r.status == 'started')
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(rideId: r.id))),
                icon: const Icon(Icons.chat_bubble_outline), label: const Text('محادثة مع السائق'),
              )),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _emergency(context),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                icon: const Icon(Icons.sos),
                label: const Text('طوارئ'),
              ),
            ),
            if (r.status == 'accepted' || r.status == 'arrived')
              TextButton(
                onPressed: _cancel,
                child: const Text('إلغاء الرحلة', style: TextStyle(color: AppColors.red)),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────── التقييم ─────────────────────────
class _RatingView extends StatefulWidget {
  final Ride ride;
  const _RatingView({required this.ride});
  @override
  State<_RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends State<_RatingView> {
  int _stars = 5;
  final _c = TextEditingController();
  bool _busy = false;

  Future<void> _done({required bool send}) async {
    setState(() => _busy = true);
    try {
      if (send && !widget.ride.riderRated) {
        await RideService.rate(widget.ride, _stars, _c.text.trim());
      } else {
        await RideService.clearActive();
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر إرسال التقييم', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.check_circle, size: 80, color: AppColors.green),
      const SizedBox(height: 8),
      const Text('تمت الرحلة بنجاح', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(money(r.finalPrice), textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary)),
      Text('الدفع: نقداً للسائق', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('${r.distanceKm.toStringAsFixed(1)} كم • ${r.durationMin.round()} دقيقة', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      const Text('قيّم الرحلة', textAlign: TextAlign.center),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 38,
            onPressed: () => setState(() => _stars = i),
            icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: AppColors.orange),
          ),
      ]),
      TextField(controller: _c, maxLines: 3, decoration: const InputDecoration(hintText: 'أضف تعليقاً (اختياري)')),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _busy ? null : () => _done(send: true), child: const Text('إرسال التقييم')),
      TextButton(onPressed: _busy ? null : () => _done(send: false), child: const Text('تخطي')),
    ]);
  }
}

class _CancelledView extends StatelessWidget {
  final Ride ride;
  const _CancelledView({required this.ride});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cancel, size: 72, color: AppColors.red),
            const SizedBox(height: 10),
            const Text('تم إلغاء الرحلة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await RideService.clearActive();
                } catch (_) {}
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('حسناً'),
            ),
          ]),
        ),
      );
}
