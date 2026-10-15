import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../widgets/common.dart';
import 'place_search_screen.dart';
import 'trip_request_screen.dart';

const List<int> _weekOrder = [6, 7, 1, 2, 3, 4, 5]; // السبت → الجمعة (DateTime.weekday)
const Map<int, String> _dayNames = {6: 'السبت', 7: 'الأحد', 1: 'الإثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة'};

String _schedule(Map<String, dynamic> t) {
  final mode = (t['mode'] ?? 'once').toString();
  final days = (t['days'] is List ? (t['days'] as List) : const []).map((e) => (e as num).toInt()).toList();
  final names = [for (final d in _weekOrder) if (days.contains(d)) _dayNames[d]];
  final time = (t['time'] ?? '').toString();
  final when = mode == 'once' ? (t['date'] ?? '').toString() : mode == 'days' ? names.join('، ') : (names.isEmpty ? 'كل يوم' : 'كل يوم عدا ${names.join('، ')}');
  return '$when • $time';
}

/// الرحلات اليومية: حفظ رحلة (بداية ونهاية + تاريخ ووقت، أو أيام محددة، أو طوال الأسبوع ما عدا أيام).
class DailyTripsScreen extends StatelessWidget {
  const DailyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseDatabase.instance.ref('users/$uid/dailyTrips');
    return Scaffold(
      appBar: AppBar(title: const Text('الرحلات اليومية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _NewDailyTrip(uid: uid))),
        icon: const Icon(Icons.add),
        label: const Text('رحلة جديدة'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (c, s) {
          if (s.hasError) return const ErrorView('تعذر تحميل الرحلات');
          if (!s.hasData) return const LoadingView();
          final items = asMap(s.data!.snapshot.value).entries.map((e) => {...asMap(e.value), '_id': e.key}).toList()
            ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          if (items.isEmpty) return const EmptyView('لا توجد رحلات محفوظة', icon: Icons.event_repeat);
          return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
            for (final t in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asMap(t['pickup'])['address']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                    Text(asMap(t['dest'])['address']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(_schedule(t), style: const TextStyle(color: Colors.grey)),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripRequestScreen(pickup: Place.fromMap(asMap(t['pickup'])), dest: Place.fromMap(asMap(t['dest']))))),
                        icon: const Icon(Icons.local_taxi_outlined),
                        label: const Text('اطلب الآن'),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                        onPressed: () async {
                          if (await confirmDialog(context, 'حذف الرحلة', 'هل تريد حذف هذه الرحلة؟')) await ref.child(t['_id'].toString()).remove();
                        },
                      ),
                    ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _NewDailyTrip extends StatefulWidget {
  final String uid;
  const _NewDailyTrip({required this.uid});
  @override
  State<_NewDailyTrip> createState() => _NewDailyTripState();
}

class _NewDailyTripState extends State<_NewDailyTrip> {
  Place? _from, _to;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _mode = 'once'; // once | days | week
  final Set<int> _days = {};
  bool _busy = false;

  Future<void> _pick(bool from) async {
    final p = await Navigator.push<Place>(context, MaterialPageRoute(builder: (_) => PlaceSearchScreen(title: from ? 'نقطة البداية' : 'نقطة النهاية')));
    if (p != null) setState(() => from ? _from = p : _to = p);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _save() async {
    if (_from == null || _to == null) return showSnack(context, 'حدد نقطة البداية والنهاية', error: true);
    if (_mode == 'days' && _days.isEmpty) return showSnack(context, 'اختر يوماً واحداً على الأقل', error: true);
    setState(() => _busy = true);
    try {
      final ref = FirebaseDatabase.instance.ref('users/${widget.uid}/dailyTrips').push();
      await ref.set({
        'pickup': _from!.toMap(),
        'dest': _to!.toMap(),
        'time': '${_two(_time.hour)}:${_two(_time.minute)}',
        'mode': _mode,
        if (_mode == 'once') 'date': '${_date.year}-${_two(_date.month)}-${_two(_date.day)}',
        if (_mode != 'once') 'days': _days.toList()..sort(),
        'createdAt': ServerValue.timestamp,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر الحفظ'), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('رحلة جديدة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(tileColor: AppColors.card, leading: const Icon(Icons.trip_origin, color: AppColors.primary), title: Text(_from?.address ?? 'نقطة البداية'), onTap: () => _pick(true)),
          const SizedBox(height: 8),
          ListTile(tileColor: AppColors.card, leading: const Icon(Icons.location_on, color: AppColors.red), title: Text(_to?.address ?? 'نقطة النهاية'), onTap: () => _pick(false)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for (final m in const [('once', 'تاريخ محدد'), ('days', 'أيام محددة'), ('week', 'طوال الأسبوع ما عدا...')])
              ChoiceChip(label: Text(m.$2), selected: _mode == m.$1, onSelected: (_) => setState(() => _mode = m.$1)),
          ]),
          const SizedBox(height: 12),
          if (_mode == 'once')
            ListTile(
              tileColor: AppColors.card,
              leading: const Icon(Icons.calendar_today),
              title: Text('${_date.year}/${_date.month}/${_date.day}'),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _date = d);
              },
            )
          else ...[
            Text(_mode == 'days' ? 'اختر الأيام' : 'اختر الأيام المستثناة', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final d in _weekOrder)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(_dayNames[d]!),
                      selected: _days.contains(d),
                      onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            tileColor: AppColors.card,
            leading: const Icon(Icons.access_time),
            title: Text(_time.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 20),
          AppButton('حفظ الرحلة', onPressed: _save, busy: _busy),
        ]),
      );
}
