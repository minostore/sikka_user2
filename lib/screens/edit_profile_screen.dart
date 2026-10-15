import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/phone_field.dart';

/// تعديل الملف الشخصي للمستخدم: الصورة والاسم والبريد الإلكتروني ورقم الهاتف.
/// (تطبيق المستخدم فقط — السائق يتواصل مع خدمة العملاء.)
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditProfileScreen({super.key, required this.data});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _name = TextEditingController(text: (widget.data['name'] ?? '').toString());
  late final _email = TextEditingController(text: (widget.data['email'] ?? '').toString());
  late final _phone = TextEditingController(text: _digits((widget.data['phone'] ?? '').toString()));
  String? _photo;
  bool _busy = false, _uploading = false;

  /// المخزَّن 20XXXXXXXXXX → الأرقام العشرة بعد +20
  static String _digits(String stored) {
    var d = stored.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('20')) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  @override
  void initState() {
    super.initState();
    final p = (widget.data['photoUrl'] ?? '').toString();
    if (p.startsWith('http')) _photo = p;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploading) return;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800, maxHeight: 800);
      if (x == null) return;
      setState(() => _uploading = true);
      final ref = FirebaseStorage.instance.ref('riderAvatars/$_uid/avatar.jpg');
      await ref.putFile(File(x.path), SettableMetadata(contentType: 'image/jpeg'));
      final url = '${await ref.getDownloadURL()}&t=${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseDatabase.instance.ref('users/$_uid/photoUrl').set(url);
      if (mounted) {
        setState(() => _photo = url);
        showSnack(context, 'تم تحديث الصورة');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر تحديث الصورة'), error: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    final name = _name.text.trim(), email = _email.text.trim();
    if (name.length < 3) return showSnack(context, 'أدخل الاسم الكامل', error: true);
    if (!email.contains('@') || !email.contains('.')) return showSnack(context, 'أدخل بريداً إلكترونياً صحيحاً', error: true);
    if (!PhoneField.isValid(_phone.text)) return showSnack(context, PhoneField.errorText, error: true);
    setState(() => _busy = true);
    try {
      await FirebaseDatabase.instance.ref('users/$_uid').update({
        'name': name,
        'email': email,
        'phone': '20${_phone.text.trim()}',
      });
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      if (mounted) {
        showSnack(context, 'تم حفظ التعديلات');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر حفظ التعديلات'), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary,
                  backgroundImage: _photo != null ? NetworkImage(_photo!) : null,
                  child: _uploading
                      ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.navy))
                      : _photo != null
                          ? null
                          : const Icon(Icons.person, size: 46, color: AppColors.navy),
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 2)),
                    child: const Icon(Icons.photo_camera, size: 16, color: AppColors.navy),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          TextField(controller: _name, decoration: fieldDec(context, 'الاسم', Icons.person_outline)),
          const SizedBox(height: 14),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: fieldDec(context, 'البريد الإلكتروني', Icons.mail_outline)),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text('تغيير البريد هنا يحدّث بيانات التواصل فقط، ولا يغيّر بريد تسجيل الدخول.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 14),
          PhoneField(controller: _phone),
          const SizedBox(height: 22),
          AppButton('حفظ', onPressed: _save, busy: _busy),
        ]),
      );
}
