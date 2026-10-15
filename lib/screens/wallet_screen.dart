import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('wallets/$uid').onValue,
        builder: (c, s) {
          if (s.hasError) return const ErrorView('تعذر تحميل المحفظة');
          if (!s.hasData) return const LoadingView();
          final m = asMap(s.data!.snapshot.value);
          final tx = asMap(m['tx']).entries.map((e) => asMap(e.value)).toList()
            ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          final topups = asMap(m['topups']).entries.map((e) => asMap(e.value)).toList()
            ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          return ListView(padding: const EdgeInsets.all(14), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                const Text('الرصيد الحالي', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(money(numD(m['balance'])),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            const Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.bold)),
            if (tx.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد عمليات', style: TextStyle(color: Colors.grey))),
            for (final t in tx)
              ListTile(
                title: Text((t['title'] ?? 'عملية').toString()),
                subtitle: Text(_transactionDetails(t)),
                trailing: Text('${numD(t['amount']) >= 0 ? '+' : ''}${numD(t['amount']).toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: numD(t['amount']) >= 0 ? AppColors.green : AppColors.red)),
              ),
          ]);
        },
      ),
    );
  }
}


/// يوضح مصدر الحركة والمرجع المرتبط بها بجانب التاريخ، مع التوافق مع السجلات القديمة.
String _transactionDetails(Map<String, dynamic> t) {
  final parts = <String>[dateLabel((t['createdAt'] as num?)?.toInt())];
  final rawSource = (t['source'] ?? t['type'] ?? t['category'] ?? '').toString().trim();
  const sourceLabels = <String, String>{
    'ride': 'رحلة', 'trip': 'رحلة', 'commission': 'عمولة',
    'topup': 'شحن رصيد', 'wallet_topup': 'شحن رصيد',
    'refund': 'استرداد', 'transfer': 'تحويل', 'adjustment': 'تسوية إدارية',
    'cashout': 'سحب أرباح', 'payout': 'صرف أرباح',
  };
  if (rawSource.isNotEmpty) parts.add(sourceLabels[rawSource.toLowerCase()] ?? rawSource);
  final rideId = (t['rideId'] ?? t['ride_id'] ?? '').toString().trim();
  final reference = (t['reference'] ?? t['referenceId'] ?? t['requestId'] ?? '').toString().trim();
  if (rideId.isNotEmpty) parts.add('رحلة #${rideId.length > 8 ? rideId.substring(0, 8) : rideId}');
  else if (reference.isNotEmpty) parts.add('مرجع #${reference.length > 8 ? reference.substring(0, 8) : reference}');
  return parts.join(' • ');
}
