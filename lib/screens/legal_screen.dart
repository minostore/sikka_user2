import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class _LegalPage {
  final String id, title, body;
  const _LegalPage(this.id, this.title, this.body);
}

const List<_LegalPage> _defaultPages = [
  _LegalPage(
    'terms',
    'شروط الاستخدام',
    'باستخدامك التطبيق فأنت توافق على: تقديم بيانات صحيحة، الالتزام بالسعر المتفق عليه مع السائق، احترام السائقين والركاب، وعدم إساءة استخدام التطبيق.',
  ),
  _LegalPage(
    'privacy',
    'سياسة الخصوصية',
    'نستخدم موقعك أثناء استخدام التطبيق فقط لتحديد الالتقاط وتتبع الرحلة، ولا نشاركه مع أي جهة خارج الرحلة. يمكنك طلب حذف بياناتك عبر الدعم.',
  ),
];

/// شروط الاستخدام وسياسة الخصوصية (وأي صفحات أخرى تضيفها الإدارة من لوحة التحكم ← محتوى التطبيق).
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final Future<List<_LegalPage>> _f = _load();

  Future<List<_LegalPage>> _load() async {
    try {
      final raw = (await FirebaseDatabase.instance.ref('settings/legal/pages').get()).value;
      final entries = <MapEntry<String, Map<String, dynamic>>>[];
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) entries.add(MapEntry(k.toString(), Map<String, dynamic>.from(v)));
        });
      } else if (raw is List) {
        for (var i = 0; i < raw.length; i++) {
          if (raw[i] is Map) entries.add(MapEntry('$i', Map<String, dynamic>.from(raw[i] as Map)));
        }
      }
      final list = entries.where((e) => e.value['active'] != false && (e.value['title'] ?? '').toString().trim().isNotEmpty).toList()
        ..sort((a, b) => ((a.value['order'] as num?) ?? 0).compareTo((b.value['order'] as num?) ?? 0));
      if (list.isNotEmpty) {
        return [for (final e in list) _LegalPage(e.key, e.value['title'].toString().trim(), (e.value['body'] ?? '').toString())];
      }
    } catch (_) {}
    return _defaultPages;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الشروط والخصوصية')),
        body: FutureBuilder<List<_LegalPage>>(
          future: _f,
          builder: (context, snap) {
            if (!snap.hasData) return const LoadingView();
            final pages = snap.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final p in pages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LegalPageScreen(page: p))),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.description_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        const Icon(Icons.chevron_left),
                      ]),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _LegalPageScreen extends StatelessWidget {
  final _LegalPage page;
  const _LegalPageScreen({required this.page});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(page.title)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          SelectableText(page.body, style: const TextStyle(fontSize: 15.5, height: 1.8)),
        ]),
      );
}
