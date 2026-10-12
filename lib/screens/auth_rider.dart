import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

// ───────────── رسومات التصميم ─────────────
class SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final sky = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFFFF), Color(0xFFE3F0F5)]).createShader(Offset.zero & s);
    c.drawRect(Offset.zero & s, sky);
    final b = Paint()..color = const Color(0xFFCFE3EC);
    final b2 = Paint()..color = const Color(0xFFDDEBF1);
    final spec = [
      [0.02, 0.10, 0.42], [0.10, 0.08, 0.60], [0.19, 0.09, 0.34], [0.30, 0.07, 0.50],
      [0.62, 0.09, 0.38], [0.72, 0.08, 0.55], [0.81, 0.09, 0.32], [0.90, 0.09, 0.46],
    ];
    for (var i = 0; i < spec.length; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * spec[i][0], s.height * (0.78 - spec[i][2]), s.width * spec[i][1], s.height * spec[i][2]), const Radius.circular(3));
      c.drawRRect(r, i.isEven ? b : b2);
    }
    final g = Paint()..color = const Color(0xFF2E8B73);
    for (final x in [0.08, 0.17, 0.82, 0.92]) {
      c.drawCircle(Offset(s.width * x, s.height * 0.80), s.width * 0.055, g);
    }
    // السيارة
    final cx = s.width * 0.5, by = s.height * 0.86, w = s.width * 0.72;
    final body = Path()
      ..moveTo(cx - w / 2, by)
      ..lineTo(cx - w / 2, by - s.height * 0.07)
      ..quadraticBezierTo(cx - w / 2, by - s.height * 0.10, cx - w * 0.38, by - s.height * 0.10)
      ..lineTo(cx - w * 0.22, by - s.height * 0.10)
      ..lineTo(cx - w * 0.12, by - s.height * 0.17)
      ..lineTo(cx + w * 0.18, by - s.height * 0.17)
      ..lineTo(cx + w * 0.30, by - s.height * 0.10)
      ..lineTo(cx + w * 0.40, by - s.height * 0.095)
      ..quadraticBezierTo(cx + w / 2, by - s.height * 0.08, cx + w / 2, by - s.height * 0.05)
      ..lineTo(cx + w / 2, by)
      ..close();
    c.drawShadow(body, Colors.black26, 6, true);
    c.drawPath(body, Paint()..color = const Color(0xFFF6F9FB));
    final win = Paint()..color = const Color(0xFFBFD9E4);
    c.drawPath(
        Path()
          ..moveTo(cx - w * 0.19, by - s.height * 0.105)
          ..lineTo(cx - w * 0.10, by - s.height * 0.16)
          ..lineTo(cx + w * 0.05, by - s.height * 0.16)
          ..lineTo(cx + w * 0.05, by - s.height * 0.105)
          ..close(),
        win);
    c.drawPath(
        Path()
          ..moveTo(cx + w * 0.09, by - s.height * 0.105)
          ..lineTo(cx + w * 0.09, by - s.height * 0.16)
          ..lineTo(cx + w * 0.17, by - s.height * 0.16)
          ..lineTo(cx + w * 0.26, by - s.height * 0.105)
          ..close(),
        win);
    for (final x in [-0.28, 0.30]) {
      c.drawCircle(Offset(cx + w * x, by), s.height * 0.035, Paint()..color = const Color(0xFF1B2A38));
      c.drawCircle(Offset(cx + w * x, by), s.height * 0.016, Paint()..color = const Color(0xFFB9C6CF));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class PhonePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final cloud = Paint()..color = const Color(0xFFE6F1F6);
    c.drawCircle(Offset(s.width * 0.22, s.height * 0.28), s.width * 0.16, cloud);
    c.drawCircle(Offset(s.width * 0.34, s.height * 0.22), s.width * 0.13, cloud);
    // الهاتف
    final ph = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.45, s.height * 0.02, s.width * 0.34, s.height * 0.86), const Radius.circular(22));
    c.drawRRect(ph, Paint()..color = const Color(0xFF0B3A52));
    final scr = RRect.fromRectAndRadius(ph.outerRect.deflate(7), const Radius.circular(16));
    c.drawRRect(scr, Paint()..color = const Color(0xFFEAF3F7));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    c.drawLine(Offset(scr.left, scr.top + scr.height * 0.45), Offset(scr.right, scr.top + scr.height * 0.35), road);
    c.drawLine(Offset(scr.left + scr.width * 0.4, scr.top), Offset(scr.left + scr.width * 0.55, scr.bottom), road);
    // الدبوس
    final pin = Offset(scr.center.dx, scr.top + scr.height * 0.33);
    c.drawCircle(pin, 22, Paint()..color = const Color(0xFFF2A93B));
    c.drawCircle(pin, 8, Paint()..color = Colors.white);
    // الفتاة
    c.drawCircle(Offset(s.width * 0.30, s.height * 0.50), 26, Paint()..color = const Color(0xFF2C1F2E)); // الشعر
    c.drawCircle(Offset(s.width * 0.31, s.height * 0.52), 19, Paint()..color = const Color(0xFFF2C6A5));
    final torso = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.14, s.height * 0.60, s.width * 0.34, s.height * 0.30), const Radius.circular(40));
    c.drawRRect(torso, Paint()..color = const Color(0xFFF4B73A));
    c.drawLine(Offset(s.width * 0.42, s.height * 0.68), Offset(s.width * 0.52, s.height * 0.55), Paint()..color = const Color(0xFFF2C6A5)..strokeWidth = 9..strokeCap = StrokeCap.round);
    final g = Paint()..color = const Color(0xFF2E8B73);
    c.drawCircle(Offset(s.width * 0.80, s.height * 0.90), 22, g);
    c.drawCircle(Offset(s.width * 0.90, s.height * 0.86), 16, g);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 58});
  @override
  Widget build(BuildContext context) => Text(AppConfig.appName,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1));
}

// ───────────── شاشة البداية ─────────────
class RiderSplash extends StatefulWidget {
  final Future<Widget?> Function() resolveHome; // الصفحة الرئيسية إن كان مسجلاً، وإلا null
  final Widget Function() onboarding;
  const RiderSplash({super.key, required this.resolveHome, required this.onboarding});
  @override
  State<RiderSplash> createState() => _RiderSplashState();
}

class _RiderSplashState extends State<RiderSplash> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final t = DateTime.now();
    Widget? home;
    try {
      home = await widget.resolveHome();
    } catch (_) {}
    if (home != null) {
      final left = 1200 - DateTime.now().difference(t).inMilliseconds;
      if (left > 0) await Future.delayed(Duration(milliseconds: left));
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => home!));
    } else if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            const SizedBox(height: 70),
            const Wordmark(),
            const SizedBox(height: 6),
            const Text('من مكانك ... إلى كل مكان', style: TextStyle(color: AppColors.primary, fontSize: 15)),
            Expanded(child: CustomPaint(painter: SkylinePainter(), size: Size.infinite)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 22, height: 7, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5))),
              const SizedBox(width: 6),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
            ]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _ready
                  ? AppButton('ابدأ الآن', onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.onboarding())))
                  : const SizedBox(height: 54, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))),
            ),
          ]),
        ),
      );
}

// ───────────── التعريف ─────────────
class OnboardingScreen extends StatelessWidget {
  final Widget Function() homeBuilder;
  const OnboardingScreen({super.key, required this.homeBuilder});
  @override
  Widget build(BuildContext context) {
    Widget item(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 16, color: Colors.white)),
            const SizedBox(width: 12),
            Text(t, style: const TextStyle(fontSize: 16)),
          ]),
        );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(20), child: CustomPaint(painter: PhonePainter(), size: Size.infinite))),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('تنقل بحرية\nبشرطك الخاصة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.35, color: AppColors.ink)),
                const SizedBox(height: 12),
                item('حدد سعرك المناسب'),
                item('اختر السائق المناسب'),
                item('رحلات آمنة وموثوقة'),
                const Spacer(),
                AppButton('التالي',
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: homeBuilder)))),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────── تسجيل الدخول ─────────────
class LoginScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  const LoginScreen({super.key, required this.homeBuilder});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _busy = false;

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pass.text.isEmpty) return showSnack(context, 'أدخل البريد الإلكتروني وكلمة المرور', error: true);
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_id.text, _pass.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _id.text.contains('@') ? _id.text : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استرجاع كلمة المرور'),
        content: TextField(controller: c, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'بريدك الإلكتروني')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال الرابط')),
        ],
      ),
    );
    if (ok != true || !c.text.contains('@')) return;
    try {
      await AuthService.resetPassword(c.text);
      if (mounted) showSnack(context, 'تم إرسال رابط إعادة التعيين إلى بريدك');
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, e.code == 'user-not-found' ? 'لا يوجد حساب بهذا البريد' : AuthService.message(e), error: true);
    }
  }

  Widget _social(Widget child) => InkWell(
        onTap: () => showSnack(context, 'سيتم تفعيل هذه الطريقة قريباً'),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 10, color: Color(0x22000000))]),
          child: Center(child: child),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 70, 24, 20), children: [
            const Text('مرحباً بعودتك', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 40),
            TextField(controller: _id, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: fieldDec(context, 'البريد الإلكتروني', Icons.mail_outline)),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              decoration: fieldDec(context, 'كلمة المرور', Icons.lock_outline, suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide))),
            ),
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton(onPressed: _forgot, child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppColors.primary)))),
            const SizedBox(height: 4),
            AppButton('تسجيل الدخول', onPressed: _login, busy: _busy),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('أو تابع باستخدام', style: TextStyle(color: Colors.grey))),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ]),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _social(const Text('G', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFEA4335)))),
              const SizedBox(width: 22),
              _social(const Icon(Icons.apple, size: 30, color: Colors.black)),
            ]),
            const SizedBox(height: 40),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('ليس لديك حساب؟ ', style: TextStyle(color: Colors.grey)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(homeBuilder: widget.homeBuilder))),
                child: const Text('تسجيل جديد', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
            ]),
          ]),
        ),
      );
}

// ───────────── إنشاء حساب ─────────────
class RegisterScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  const RegisterScreen({super.key, required this.homeBuilder});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _phone = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  bool _agree = false, _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) return showSnack(context, 'أدخل الاسم الكامل', error: true);
    if (!AuthService.isValidPhone(_phone.text)) return showSnack(context, 'أدخل رقم موبايل مصري صحيح (مثال: 01012345678)', error: true);
    if (!_email.text.contains('@') || !_email.text.contains('.')) return showSnack(context, 'أدخل بريداً إلكترونياً صحيحاً', error: true);
    if (_pass.text.length < 6) return showSnack(context, 'كلمة المرور 6 أحرف على الأقل', error: true);
    if (!_agree) return showSnack(context, 'يجب الموافقة على الشروط والأحكام', error: true);
    setState(() => _busy = true);
    try {
      await AuthService.register(name: _name.text.trim(), phone: _phone.text, email: _email.text.trim(), password: _pass.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('إنشاء حساب'), backgroundColor: Colors.white),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(controller: _name, decoration: fieldDec(context, 'الاسم الكامل', Icons.person_outline)),
          const SizedBox(height: 14),
          TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: fieldDec(context, 'رقم الموبايل (01xxxxxxxxx)', Icons.phone_outlined)),
          const SizedBox(height: 14),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: fieldDec(context, 'البريد الإلكتروني', Icons.mail_outline)),
          const SizedBox(height: 14),
          TextField(controller: _pass, obscureText: true, decoration: fieldDec(context, 'كلمة المرور', Icons.lock_outline)),
          CheckboxListTile(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('أوافق على الشروط والأحكام'),
          ),
          const SizedBox(height: 8),
          AppButton('إنشاء الحساب', onPressed: _submit, busy: _busy),
        ]),
      );
}
