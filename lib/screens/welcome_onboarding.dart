import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/config.dart';
import 'auth_rider.dart';

/// رحلة تعريفية من أربع خطوات لتطبيق المستخدم، تظهر قبل تسجيل الدخول.
class SikkaWelcome extends StatefulWidget {
  final Widget Function() homeBuilder;
  const SikkaWelcome({super.key, required this.homeBuilder});

  @override
  State<SikkaWelcome> createState() => _SikkaWelcomeState();
}

class _SikkaWelcomeState extends State<SikkaWelcome> {
  final PageController _pages = PageController();
  late final Future<List<String?>> _welcomeImages;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // The onboarding screen must also work in widget tests and when Firebase
    // is temporarily unavailable. Fall back to the bundled slide images.
    _welcomeImages = _loadWelcomeImages();
  }

  Future<List<String?>> _loadWelcomeImages() async {
    try {
      final ref = FirebaseDatabase.instance.ref('settings/welcome');
      final snap = await ref.once();
      final value = snap.snapshot.value;
      final welcome = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
      final raw = welcome['riderImages'];
      final images = List<String?>.filled(4, null);
      if (raw is Map) {
        for (var i = 0; i < 4; i++) {
          final u = raw['$i']?.toString();
          if (u != null && u.startsWith('https://')) images[i] = u;
        }
      } else if (raw is List) {
        for (var i = 0; i < 4 && i < raw.length; i++) {
          final u = raw[i]?.toString();
          if (u != null && u.startsWith('https://')) images[i] = u;
        }
      }
      final legacy = welcome['riderImageUrl']?.toString();
      if (legacy != null &&
          legacy.startsWith('https://') &&
          images.every((e) => e == null))
        images[0] = legacy;
      return images;
    } catch (_) {
      return List<String?>.filled(4, null);
    }
  }

  static const _slides = <_SlideData>[
    _SlideData(
      'ابدأ رحلتك مع سِكّة',
      'مشوارك يبدأ بخطوات بسيطة — حدّد وجهتك واطلب رحلتك بسهولة.',
      'assets/onboarding/rider_start.jpg',
      Icons.directions_car_filled_rounded,
    ),
    _SlideData(
      'اختار الرحلة المناسبة',
      'راجع تفاصيل العروض واختر السائق والسعر الأنسب لك.',
      'assets/onboarding/rider_choose_trip.jpg',
      Icons.map_rounded,
    ),
    _SlideData(
      'تابع تفاصيل الرحلة',
      'بعد قبول العرض، تابع بيانات السائق ومسار الرحلة وتواصل معه من التطبيق.',
      'assets/onboarding/rider_accepted_ride.jpg',
      Icons.receipt_long_rounded,
    ),
    _SlideData(
      'وأكمل رحلتك بأمان',
      'تابع وصولك لوجهتك، وأنهِ المشوار بكل سهولة واطمئنان.',
      'assets/onboarding/rider_complete_trip.jpg',
      Icons.check_circle_rounded,
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openLogin() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => LoginScreen(homeBuilder: widget.homeBuilder),
    ),
  );

  void _next() {
    if (_index < _slides.length - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _openLogin();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF03172D), Color(0xFF082B4C), Color(0xFF031326)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Column(
                      children: const [
                        Icon(
                          Icons.add_location_alt_rounded,
                          color: Color(0xFFFFB800),
                          size: 36,
                        ),
                        Text(
                          'سِكّة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '— Sikka —',
                          style: TextStyle(
                            color: Color(0xFFFFB800),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openLogin,
                      child: const Text(
                        'تخطي',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFC23D),
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD5DFEA),
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 350,
                                  maxHeight: 360,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 4 / 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C3155),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: const Color(0xFFFFB800),
                                        width: 1.4,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 24,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: FutureBuilder<List<String?>>(
                                      future: _welcomeImages,
                                      builder: (context, snap) {
                                        final url =
                                            snap.data != null &&
                                                i < snap.data!.length
                                            ? snap.data![i]
                                            : null;
                                        final fallback = Image.asset(
                                          slide.image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Icon(
                                              slide.fallbackIcon,
                                              size: 100,
                                              color: const Color(0xFFFFB800),
                                            ),
                                          ),
                                        );
                                        final image = url == null
                                            ? fallback
                                            : Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    fallback,
                                              );
                                        return GestureDetector(
                                          onTap: () => showDialog<void>(
                                            context: context,
                                            builder: (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: image,
                                              ),
                                            ),
                                          ),
                                          child: image,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? const Color(0xFFFFB800)
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB800),
                      foregroundColor: const Color(0xFF061B31),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: _next,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _index == _slides.length - 1 ? 'ابدأ الآن' : 'التالي',
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15, top: 5),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      'لديك حساب بالفعل؟ ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: _openLogin,
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: Color(0xFFFFB800),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SlideData {
  final String title;
  final String subtitle;
  final String image;
  final IconData fallbackIcon;
  const _SlideData(this.title, this.subtitle, this.image, this.fallbackIcon);
}
