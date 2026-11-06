import 'package:flutter/material.dart';

import '../theme.dart';

/// Single animated tile: slides via AnimatedPositioned (in the board), pops on
/// merge and scales in when spawned — same animation timing as before, now a
/// flat copper-ramp tile with a soft glow on the high values.
class TileView extends StatefulWidget {
  const TileView({
    super.key,
    required this.value,
    required this.size,
    required this.fontSize,
    required this.isNew,
  });

  final int value;
  final double size;
  final double fontSize;
  final bool isNew;

  @override
  State<TileView> createState() => _TileViewState();
}

class _TileViewState extends State<TileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _appear.forward();
    } else {
      _appear.value = 1;
    }
  }

  @override
  void didUpdateWidget(TileView old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _appear.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = styleFor(widget.value);
    return AnimatedBuilder(
      animation: Listenable.merge([_appear, _pop]),
      builder: (context, _) {
        final appear = Curves.easeOut.transform(_appear.value);
        final popT = _pop.value;
        final pop = popT == 0 || popT == 1
            ? 1.0
            : 1 + 0.18 * (popT < 0.5 ? popT * 2 : (1 - popT) * 2);
        final scale = (0.2 + 0.8 * appear) * pop;
        return Opacity(
          opacity: appear,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              padding: EdgeInsets.all(widget.size * 0.08),
              decoration: BoxDecoration(
                color: st.bg,
                borderRadius: BorderRadius.circular(widget.size * 0.22),
                border: st.border != null
                    ? Border.all(color: st.border!, width: 1.4)
                    : null,
                boxShadow: st.glow != null
                    ? [
                        BoxShadow(
                          color: st.glow!,
                          blurRadius: widget.size * 0.4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              // FittedBox keeps 3-5 digit tiles inside the cell on any grid.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${widget.value}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: widget.fontSize,
                    color: st.fg,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
