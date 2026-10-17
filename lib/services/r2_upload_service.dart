import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// Uploads profile images to the existing Sikka Cloudflare Worker/R2 service.
/// The Worker must allow the `profile` upload key for any authenticated account
/// and return a public or Worker-served HTTPS URL in `url`, `publicUrl`, or `downloadUrl`.
class R2UploadService {
  static const _defaultBase = 'https://sikka-eg.online';

  static Future<Map<String, String>> uploadProfileImage({
    required File file,
    required String role,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('سجّل الدخول مرة أخرى ثم حاول رفع الصورة.');
    final cfg = (await FirebaseDatabase.instance.ref('settings/uploadApi').get())
        .value
        ?.toString()
        .trim();
    final base = (cfg != null && cfg.isNotEmpty ? cfg : _defaultBase)
        .replaceAll(RegExp(r'/+$'), '');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('تعذر الحصول على رمز تسجيل الدخول. سجّل الدخول مرة أخرى.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('ملف الصورة فارغ. اختر صورة أخرى.');
    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('حجم الصورة أكبر من 8 ميجابايت. اختر صورة أصغر.');
    }
    // الطريقة الأساسية: رابط موقّع من خادم لوحة التحكم (الدومين الرسمي) ثم رفع مباشر إلى R2.
    try {
      final r = await http
          .post(Uri.parse('${AppConfig.adminApiBase}/api/user/profile-upload-url'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'size': bytes.length}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final up = (j['url'] ?? '').toString(), pub = (j['publicUrl'] ?? '').toString();
        if (up.startsWith('https://') && pub.startsWith('https://')) {
          final put = await http.put(Uri.parse(up), headers: {'Content-Type': 'image/jpeg'}, body: bytes).timeout(const Duration(seconds: 90));
          if (put.statusCode >= 200 && put.statusCode < 300) return {'url': pub, 'path': (j['key'] ?? '').toString()};
        }
      }
    } catch (_) {}
    // The Worker derives the authenticated UID from the Firebase token; the
    // role-specific metadata is kept in the database, not trusted from the client.
    final uri = Uri.parse('$base/upload/profile');
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'image/jpeg',
        'X-Sikka-Profile-Role': role,
      },
      body: bytes,
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = response.body.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (detail.length > 180) detail = detail.substring(0, 180);
      throw HttpException('HTTP ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}');
    }
    dynamic payload;
    try { payload = jsonDecode(response.body); } catch (_) {}
    if (payload is! Map) {
      throw Exception('خدمة R2 لم تُرجع بيانات الصورة. راجع إعداد Worker.');
    }
    final url = (payload['url'] ?? payload['publicUrl'] ?? payload['downloadUrl'] ?? '').toString();
    final path = (payload['key'] ?? payload['path'] ?? payload['objectKey'] ?? '').toString();
    if (!url.startsWith('https://')) {
      throw Exception('تم رفع الصورة لكن Worker لم يُرجع رابط HTTPS صالحًا. راجع مسار /file في Worker.');
    }
    return {'url': url, if (path.isNotEmpty) 'path': path};
  }
}
