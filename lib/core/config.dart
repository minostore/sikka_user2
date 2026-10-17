import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

/// إعدادات التطبيق — عدّل القيم هنا فقط (العملة، رمز الدولة، مصدر الخرائط...)
class AppConfig {
  static const appName = 'Sikka User';
  static const role = 'rider'; // rider | driver
  static const logoAsset = 'assets/branding/logo.png';
  static const logoBg = Color(0xFF0A0F1B); // لون خلفية صورة الشعار
  static const emergencyNumber = '122'; // رقم نجدة الشرطة في مصر
  static const currency = 'ج.م';
  static const countryCode = '+20';
  static const packageName = 'com.sikka.user';
  // الدومين الرسمي للوحة التحكم (رفع الصور والتحديثات)
  static const adminApiBase = 'https://www.sikka-eg.online';
  static const userAgent = 'MishwarApp/1.0 ($packageName)';
  // مصدر بلاطات OpenStreetMap. يجب الالتزام بسياسة الاستخدام وإظهار الإسناد.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultCenter = LatLng(30.0444, 31.2357);
  static const nearbyRadiusKm = 8.0;
}
