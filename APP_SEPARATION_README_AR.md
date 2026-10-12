# Sikka User — فصل التطبيقين

- نوع الحساب المسموح: `rider` فقط.
- اسم العرض: `Sikka User`.
- معرّف Android المطلوب: `com.sikka.user`.
- شاشات التطبيق الآخر لا تُستخدم كواجهة أساسية، والتحقق من الدور يتم عند تسجيل الدخول وبوابة التطبيق.

## تجهيز Android وبناء APK
من جذر المشروع شغّل `bash tool/setup_platforms.sh` (أو `flutter create . --platforms=android` إذا كان Flutter مثبتاً)، ثم تأكد أن `applicationId` في `android/app/build.gradle` يساوي المعرّف المذكور أعلاه، وبعدها نفّذ `flutter pub get` و`flutter build apk --release`.

ملاحظة: هذا الأرشيف يحتوي مصدر Flutter ولا يحتوي مجلد `android/` أو APK جاهزاً.

## إصلاح فصل الواجهات

تم ربط شاشة الترحيب وتسجيل الدخول في تطبيق المستخدم بملف `auth_rider.dart` بدل `auth_driver.dart` حتى لا تظهر شاشة تسجيل/دخول السائق من داخل تطبيق المستخدم.
