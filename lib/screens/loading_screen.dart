import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../watch.dart';
import 'splash_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final AnimationController _appearCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  double _progress = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) return;
      setState(() {
        _progress =
            math.min(1.0, _progress + (math.Random().nextDouble() * 0.04 + 0.01));
      });
    });

    await RyzixStore.I.init();

    final elapsed = DateTime.now().difference(start);
    const minimum = Duration(milliseconds: 1050);
    if (elapsed < minimum) await Future.delayed(minimum - elapsed);

    while (_progress < 1.0) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _ticker?.cancel();

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => const SplashScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _appearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final barW = 110 * u;
    final barH = 3 * u;
    final pct = (_progress.clamp(0.0, 1.0) * 100).toInt();

    return FadeTransition(
      opacity: Tween<double>(begin: 0.82, end: 1.0).animate(CurvedAnimation(
        parent: _pulseCtrl,
        curve: Curves.easeInOut,
      )),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RYZIX',
                style: wLabel(context.fs(11), color: C.copper, ls: 5)),
            SizedBox(height: 6 * u),
            // thin watch-face numerals, gently floating
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, child) {
                final dy = math.sin(_floatCtrl.value * math.pi) * (-4.0 * u);
                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: Text('2048',
                  style: wLight(context.fs(64), ls: -2.5)),
            ),
            SizedBox(height: 22 * u),
            SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.5), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: _appearCtrl,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOut))),
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _appearCtrl,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
                child: Column(
                  children: [
                    Container(
                      width: barW,
                      height: barH,
                      decoration: BoxDecoration(
                        color: const Color(0x33E1BBA4),
                        borderRadius: BorderRadius.circular(barH),
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeIn,
                        width: barW * _progress.clamp(0.0, 1.0),
                        height: barH,
                        decoration: BoxDecoration(
                          color: C.copper,
                          borderRadius: BorderRadius.circular(barH),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x80E37C48), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8 * u),
                    Text('$pct%',
                        style: wLabel(context.fs(10), color: C.blush, ls: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
