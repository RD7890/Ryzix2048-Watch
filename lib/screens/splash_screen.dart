import 'package:flutter/material.dart';

import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import '../watch.dart';
import '../widgets/modals.dart';
import '../widgets/wbutton.dart';
import 'home_screen.dart';

/// Slide navigation engine (mirrors .screen / .exit-left transitions).
Route<T> slideRoute<T>(Widget page, {String? name}) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, anim, secondary, child) {
      const curve = Cubic(0.25, 1, 0.5, 1);
      // Same easing shape in both directions: back feels as snappy as forward.
      final inAnim =
          CurvedAnimation(parent: anim, curve: curve, reverseCurve: curve.flipped);
      final outAnim = CurvedAnimation(
          parent: secondary, curve: curve, reverseCurve: curve.flipped);
      return SlideTransition(
        position: Tween(begin: Offset.zero, end: const Offset(-1, 0))
            .animate(outAnim),
        child: SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(inAnim),
          child: FadeTransition(opacity: inAnim, child: child),
        ),
      );
    },
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _store = RyzixStore.I;

  void _enter(String name) {
    _store.signIn(name);
    Sfx.I.click();
    Navigator.of(context)
        .push(slideRoute(const HomeScreen(), name: 'home'))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<String?> _askName() =>
      showRyzixModal<String>(context, const _NamePrompt(), click: false);

  Future<void> _playNow() async {
    Sfx.I.click();
    final existing = _store.currentUser;
    if (existing != null && existing != 'Guest') {
      _enter(existing);
      return;
    }
    final name = await _askName();
    if (name == null) return;
    _enter(name);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final user = _store.currentUser;
    final hasProfile = user != null && user != 'Guest';
    final displayName = hasProfile ? user : 'Guest';

    return Stack(
      children: [
        // keep the bottom (buttons) readable over the planet
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.72),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            // date header, like the reference face: FRI ........ 11/06
            Padding(
              padding: EdgeInsets.fromLTRB(30 * u, 12 * u, 28 * u, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(WatchStamp.day(),
                      style: wLabel(context.fs(11),
                          color: C.text, ls: 0.4, weight: FontWeight.w400)),
                  Text(WatchStamp.date(),
                      style: wLabel(context.fs(11),
                          color: C.text, ls: 0.4, weight: FontWeight.w400)),
                ],
              ),
            ),
            SizedBox(height: 4 * u),
            // the big thin numerals
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('2048', style: wLight(context.fs(68), ls: -3)),
            ),
            SizedBox(height: 5 * u),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('RYZIX  ·  SLIDE  ·  MERGE',
                  style: wLabel(context.fs(9), color: C.copper, ls: 1.8)),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(14 * u, 0, 14 * u, 12 * u),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AccountChip(
                    name: displayName,
                    best: _store.overallBest,
                    onSwitch: () async {
                      Sfx.I.click();
                      final name = await _askName();
                      if (name != null) _enter(name);
                    },
                  ),
                  SizedBox(height: 7 * u),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: WButton(
                          onTap: _playNow,
                          height: 34,
                          child: WLabel(
                              hasProfile ? 'Continue' : 'Play now',
                              icon: Icons.play_arrow_rounded),
                        ),
                      ),
                      SizedBox(width: 6 * u),
                      Expanded(
                        flex: 3,
                        child: WButton(
                          style: WStyle.ghost,
                          height: 34,
                          onTap: () => _enter('Guest'),
                          child: const Text('GUEST'),
                        ),
                      ),
                    ],
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

/// Glass chip: avatar + "Name · Best N" + swap icon.
class _AccountChip extends StatelessWidget {
  const _AccountChip(
      {required this.name, required this.best, required this.onSwitch});
  final String name;
  final int best;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSwitch,
      child: Container(
        height: 30 * u,
        padding: EdgeInsets.only(left: 4 * u, right: 10 * u),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x40E1BBA4), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 22 * u,
              height: 22 * u,
              decoration: const BoxDecoration(
                  color: C.copper, shape: BoxShape.circle),
              child: Icon(Icons.person_rounded,
                  size: 13 * u, color: C.onCopper),
            ),
            SizedBox(width: 7 * u),
            Expanded(
              child: Text(
                '$name  ·  Best $best',
                overflow: TextOverflow.ellipsis,
                style: wLabel(context.fs(10.5), color: C.cream, ls: 0.2),
              ),
            ),
            SizedBox(width: 6 * u),
            Icon(Icons.swap_horiz_rounded, size: 13 * u, color: C.blush),
          ],
        ),
      ),
    );
  }
}

/// "Who is playing?" prompt (shown as a watch modal).
class _NamePrompt extends StatefulWidget {
  const _NamePrompt();
  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  final _c = TextEditingController(
      text: RyzixStore.I.currentUser == 'Guest'
          ? ''
          : (RyzixStore.I.currentUser ?? ''));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final known = RyzixStore.I.users.where((x) => x != 'Guest').toList();
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: c, width: 1.2),
        );
    return ModalCard(children: [
      Text('Who is playing?',
          textAlign: TextAlign.center, style: wLight(context.fs(16))),
      Text('Scores are saved per player on this device.',
          textAlign: TextAlign.center,
          style: wLabel(context.fs(9),
              color: C.dim, ls: 0.2, weight: FontWeight.w400)),
      TextField(
        controller: _c,
        autofocus: true,
        maxLength: 16,
        textCapitalization: TextCapitalization.words,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _submit(),
        style: wLabel(context.fs(12), color: C.cream, ls: 0.3),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Player name',
          hintStyle: wLabel(context.fs(12),
              color: C.dim, ls: 0.3, weight: FontWeight.w400),
          filled: true,
          fillColor: C.surface2,
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12 * u, vertical: 9 * u),
          border: border(C.line),
          enabledBorder: border(C.line),
          focusedBorder: border(C.copper),
        ),
      ),
      if (known.isNotEmpty)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 5 * u,
          runSpacing: 5 * u,
          children: [
            for (final n in known)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(n),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 9 * u, vertical: 4 * u),
                  decoration: BoxDecoration(
                    color: C.surface2,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: C.line, width: 1),
                  ),
                  child: Text(n,
                      style: wLabel(context.fs(10), color: C.cream, ls: 0.2)),
                ),
              ),
          ],
        ),
      WButton(onTap: _submit, child: const Text('START')),
    ]);
  }
}
