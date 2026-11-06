import 'package:flutter/material.dart';

import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import '../watch.dart';
import 'wbutton.dart';

/// Shows [card] as a centred modal INSIDE the watch viewport (nested
/// navigator), so on a phone preview the dialog stays within the watch frame.
Future<T?> showRyzixModal<T>(BuildContext context, Widget card,
    {bool click = true}) {
  if (click) Sfx.I.click();
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierColor: const Color(0xCC000000),
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curve = anim.status == AnimationStatus.reverse
          ? Curves.easeInCubic
          : Curves.easeOutCubic;
      final t = curve.transform(anim.value);
      final u = ctx.u;
      return Opacity(
        opacity: t,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - t)),
                  child: Padding(
                    padding: EdgeInsets.all(10 * u),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 180 * u),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ModalCard extends StatelessWidget {
  const ModalCard({super.key, required this.children, this.accent});
  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 14 * u),
        decoration: BoxDecoration(
          color: const Color(0xF2120D0B),
          borderRadius: BorderRadius.circular(20 * u),
          border: Border.all(
              color: (accent ?? C.blush).withOpacity(0.25), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 24),
            BoxShadow(color: Color(0x1FE37C48), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: 8 * u),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Round icon badge with a soft copper glow, used at the top of modals.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.color = C.copper});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = 34 * context.u;
    return Center(
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.16),
          border: Border.all(color: color.withOpacity(0.7), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.25), blurRadius: 14),
          ],
        ),
        child: Icon(icon, size: d * 0.5, color: color),
      ),
    );
  }
}

class ResultModal extends StatelessWidget {
  const ResultModal({
    super.key,
    required this.title,
    required this.score,
    this.best = 0,
    this.player = 'Guest',
  });
  final String title;
  final int score;
  final int best;
  final String player;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final isRecord = title.startsWith('New Best');
    return ModalCard(
      accent: isRecord ? C.gold : C.blush,
      children: [
        _Badge(
          icon: isRecord ? Icons.emoji_events_rounded : Icons.flag_rounded,
          color: isRecord ? C.gold : C.copper,
        ),
        Text(title,
            textAlign: TextAlign.center,
            style: wLabel(context.fs(12),
                color: isRecord ? C.gold : C.copper, ls: 1.4)),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$score', style: wLight(context.fs(42), ls: -1)),
          ),
        ),
        Text('FINAL SCORE',
            textAlign: TextAlign.center,
            style: wLabel(context.fs(8), color: C.dim, ls: 1.8)),
        Text('$player  ·  Best $best',
            textAlign: TextAlign.center,
            style: wLabel(context.fs(10), color: C.blush)),
        SizedBox(height: 2 * u),
        WButton(
          onTap: () {
            Sfx.I.click();
            Navigator.of(context).pop(true);
          },
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}

/// Generic confirm modal (restart / exit).
class ConfirmModal extends StatelessWidget {
  const ConfirmModal({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'CANCEL',
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = C.copper,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ModalCard(children: [
      _Badge(icon: icon, color: iconColor),
      Text(title,
          textAlign: TextAlign.center,
          style: wLight(context.fs(16), ls: 0.2)),
      Text(message,
          textAlign: TextAlign.center,
          style: wLabel(context.fs(10),
              color: C.dim, ls: 0.2, weight: FontWeight.w400)),
      WButton(
        onTap: () {
          Sfx.I.click();
          Navigator.of(context).pop(true);
        },
        child: Text(confirmLabel),
      ),
      WButton(
        style: WStyle.ghost,
        onTap: () {
          Sfx.I.click();
          Navigator.of(context).pop(false);
        },
        child: Text(cancelLabel),
      ),
    ]);
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final res = await showRyzixModal<bool>(
    context,
    ConfirmModal(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
    ),
    click: false,
  );
  return res ?? false;
}

class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key});
  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return ModalCard(children: [
      Text('Settings',
          textAlign: TextAlign.center, style: wLight(context.fs(18))),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 8 * u),
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(14 * u),
          border: Border.all(color: C.line, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.volume_up_rounded, size: 15 * u, color: C.blush),
            SizedBox(width: 6 * u),
            Expanded(
              child: Text('Audio SFX',
                  style: wLabel(context.fs(11), color: C.cream)),
            ),
            WToggle(
              value: Sfx.I.enabled,
              onChanged: (v) => setState(() {
                Sfx.I.enabled = v;
                RyzixStore.I.sfxEnabled = v;
              }),
            ),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 8 * u),
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(14 * u),
          border: Border.all(color: C.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player: ${RyzixStore.I.currentUser ?? 'Guest'}',
                style: wLabel(context.fs(11), color: C.cream)),
            SizedBox(height: 3 * u),
            Text(
                'Games ${RyzixStore.I.gamesPlayed}  ·  Best ${RyzixStore.I.overallBest}',
                style: wLabel(context.fs(10),
                    color: C.blush, weight: FontWeight.w400)),
            SizedBox(height: 3 * u),
            Text('Progress saved on this device',
                style: wLabel(context.fs(9),
                    color: C.dim, weight: FontWeight.w400)),
          ],
        ),
      ),
      WButton(
        style: WStyle.ghost,
        onTap: () {
          Sfx.I.click();
          Navigator.of(context).pop();
        },
        child: const Text('CLOSE'),
      ),
    ]);
  }
}

class ProModal extends StatelessWidget {
  const ProModal({super.key});

  @override
  Widget build(BuildContext context) {
    return ModalCard(accent: C.gold, children: [
      const _Badge(icon: Icons.workspace_premium_rounded, color: C.gold),
      Text('Ryzix Pro',
          textAlign: TextAlign.center,
          style: wLight(context.fs(20), color: C.gold)),
      Text('Unlimited UNDOs and ad-free experience.',
          textAlign: TextAlign.center,
          style: wLabel(context.fs(10),
              color: C.dim, ls: 0.2, weight: FontWeight.w400)),
      WButton(
        onTap: () {
          Sfx.I.click();
          Navigator.of(context).pop();
        },
        child: const Text('GET PRO - \$1.99'),
      ),
      WButton(
        style: WStyle.ghost,
        onTap: () {
          Sfx.I.click();
          Navigator.of(context).pop();
        },
        child: const Text('MAYBE LATER'),
      ),
    ]);
  }
}
