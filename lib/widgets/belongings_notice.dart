import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../services/local_notify.dart';

/// تنبيه للعميل بعد الوصول لوجهته: مراجعة متعلقاته الشخصية لأن الشركة غير مسؤولة عن فقدانها.
/// النص وتفعيله يُعدَّلان من لوحة التحكم ← settings/belongingsNotice.
class BelongingsNotice extends StatefulWidget {
  final String rideId;
  const BelongingsNotice({super.key, required this.rideId});
  static final Set<String> _notified = {};
  static const defaultTitle = 'راجع متعلقاتك الشخصية';
  static const defaultMessage = 'لقد وصلت إلى وجهتك. يرجى مراجعة متعلقاتك الشخصية قبل النزول من السيارة؛ الشركة غير مسؤولة عن فقدان المتعلقات.';
  @override
  State<BelongingsNotice> createState() => _BelongingsNoticeState();
}

class _BelongingsNoticeState extends State<BelongingsNotice> {
  String _title = BelongingsNotice.defaultTitle, _msg = BelongingsNotice.defaultMessage;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = asMap((await FirebaseDatabase.instance.ref('settings/belongingsNotice').get()).value);
      if (v['enabled'] == false) {
        if (mounted) setState(() => _enabled = false);
        return;
      }
      final t = (v['title'] ?? '').toString().trim(), m = (v['message'] ?? '').toString().trim();
      if (mounted) setState(() { if (t.isNotEmpty) _title = t; if (m.isNotEmpty) _msg = m; });
    } catch (_) {}
    if (_enabled && BelongingsNotice._notified.add(widget.rideId)) {
      LocalNotify.show(id: widget.rideId.hashCode & 0x3fffffff, title: _title, body: _msg, rideChannel: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFB020))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.luggage_outlined, color: Color(0xFFB36B00)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5A3500))),
            const SizedBox(height: 3),
            Text(_msg, style: const TextStyle(color: Color(0xFF5A3500), height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
