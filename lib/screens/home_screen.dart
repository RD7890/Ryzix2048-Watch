import 'package:flutter/material.dart';

import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import '../watch.dart';
import '../widgets/modals.dart';
import '../widgets/planet_backdrop.dart';
import '../widgets/wbutton.dart';
import 'game_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _startLevel(BuildContext context, int size) {
    Sfx.I.click();
    Navigator.of(context)
        .push(slideRoute(GameScreen(gridSize: size)))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Stack(
      children: [
        const Positioned.fill(child: Scrim(0.62)),
        Column(
          children: [
            SizedBox(height: 9 * u),
            // complications: streak / best / diamonds
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * u),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatChip(
                      icon: Icons.local_fire_department_rounded,
                      text: '${RyzixStore.I.streak}',
                      color: C.copper),
                  _StatChip(
                      icon: Icons.emoji_events_rounded,
                      text: '${RyzixStore.I.overallBest}',
                      color: C.gold),
                  _StatChip(
                      icon: Icons.diamond_rounded,
                      text: '${RyzixStore.I.diamonds}',
                      color: C.ice),
                ],
              ),
            ),
            SizedBox(height: 8 * u),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 12 * u),
                child: Column(
                  children: [
                    _LevelCard(
                      n: 5,
                      title: 'Master Grid',
                      subtitle: '5×5  ·  Best ${RyzixStore.I.bestFor(5)}',
                      onTap: () => _startLevel(context, 5),
                    ),
                    SizedBox(height: 6 * u),
                    _LevelCard(
                      n: 4,
                      title: 'Classic',
                      subtitle: '4×4  ·  Best ${RyzixStore.I.bestFor(4)}',
                      onTap: () => _startLevel(context, 4),
                    ),
                    SizedBox(height: 6 * u),
                    _LevelCard(
                      n: 3,
                      title: 'Blitz Speed',
                      subtitle: '3×3  ·  Best ${RyzixStore.I.bestFor(3)}',
                      onTap: () => _startLevel(context, 3),
                    ),
                    SizedBox(height: 4 * u),
                  ],
                ),
              ),
            ),
            // dock: Play (current) / Pro / Settings
            Padding(
              padding: EdgeInsets.fromLTRB(40 * u, 4 * u, 40 * u, 9 * u),
              child: WDock(
                items: [
                  const WDockItem(
                      icon: Icons.sports_esports_rounded, active: true),
                  WDockItem(
                    icon: Icons.workspace_premium_rounded,
                    color: C.gold,
                    onTap: () => showRyzixModal(context, const ProModal()),
                  ),
                  WDockItem(
                    icon: Icons.settings_rounded,
                    onTap: () =>
                        showRyzixModal(context, const SettingsModal()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * u, vertical: 3 * u),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: C.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12 * u, color: color),
          SizedBox(width: 3 * u),
          Text(text, style: wLabel(context.fs(10.5), color: C.cream, ls: 0.2)),
        ],
      ),
    );
  }
}

class _LevelCard extends StatefulWidget {
  const _LevelCard({
    required this.n,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final int n;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: EdgeInsets.symmetric(horizontal: 9 * u, vertical: 6 * u),
          decoration: BoxDecoration(
            color: const Color(0xCC120D0B),
            borderRadius: BorderRadius.circular(18 * u),
            border: Border.all(
                color: _down ? C.copper : C.line, width: 1.2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30 * u,
                height: 30 * u,
                child: CustomPaint(painter: _GlyphPainter(widget.n)),
              ),
              SizedBox(width: 9 * u),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: wLabel(context.fs(12),
                            color: C.text, ls: 0.1)),
                    SizedBox(height: 2 * u),
                    Text(widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: wLabel(context.fs(9.5),
                            color: C.dim,
                            ls: 0.2,
                            weight: FontWeight.w400)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 16 * u, color: C.copper),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny n x n board glyph, ember -> copper diagonal ramp.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.n);
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.07;
    final cell = (size.width - gap * (n - 1)) / n;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final t = (r + c) / (2 * (n - 1));
        final col = Color.lerp(C.ember, C.copper, t) ?? C.copper;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * (cell + gap), r * (cell + gap), cell, cell),
            Radius.circular(cell * 0.28),
          ),
          Paint()..color = col,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.n != n;
}
