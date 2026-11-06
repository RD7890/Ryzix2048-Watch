import 'package:flutter/material.dart';

import '../theme.dart';
import '../watch.dart';

enum WStyle { primary, ghost, quiet }

/// Flat pill button: copper fill (primary), outlined blush (ghost) or a dark
/// chip (quiet). Presses shrink slightly instead of the old 3D "lip".
class WButton extends StatefulWidget {
  const WButton({
    super.key,
    required this.onTap,
    required this.child,
    this.style = WStyle.primary,
    this.height = 32,
    this.fontSize = 11,
  });

  final VoidCallback onTap;
  final Widget child;
  final WStyle style;
  final double height; // watch units
  final double fontSize; // watch units

  @override
  State<WButton> createState() => _WButtonState();
}

class _WButtonState extends State<WButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final Color bg = switch (widget.style) {
      WStyle.primary => _down ? const Color(0xFFF08F5E) : C.copper,
      WStyle.ghost => _down ? const Color(0x22E1BBA4) : Colors.transparent,
      WStyle.quiet => C.surface2,
    };
    final Color fg = switch (widget.style) {
      WStyle.primary => C.onCopper,
      WStyle.ghost => C.cream,
      WStyle.quiet => C.cream,
    };
    final Color? border = switch (widget.style) {
      WStyle.primary => null,
      WStyle.ghost => const Color(0x80E1BBA4),
      WStyle.quiet => C.line,
    };
    final h = widget.height * u;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: h,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 10 * u),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(h / 2),
            border: border == null ? null : Border.all(color: border, width: 1.2),
            boxShadow: widget.style == WStyle.primary
                ? const [BoxShadow(color: Color(0x40E37C48), blurRadius: 12)]
                : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: context.fs(widget.fontSize),
              letterSpacing: 1.0,
              color: fg,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                  color: fg, size: context.fs(widget.fontSize + 3)),
              child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Optional icon + uppercase text for [WButton].
class WLabel extends StatelessWidget {
  const WLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon),
          SizedBox(width: 5 * context.u),
        ],
        Text(text.toUpperCase()),
      ],
    );
  }
}

/// Round icon button (header home button etc.).
class WRound extends StatefulWidget {
  const WRound({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 26,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size; // watch units
  final bool filled;
  final Color? color;

  @override
  State<WRound> createState() => _WRoundState();
}

class _WRoundState extends State<WRound> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final d = widget.size * u;
    final fg = widget.filled ? C.onCopper : (widget.color ?? C.cream);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.filled ? C.copper : const Color(0xCC120D0B),
            border: widget.filled
                ? null
                : Border.all(color: C.line, width: 1.2),
          ),
          child: Icon(widget.icon, size: d * 0.55, color: fg),
        ),
      ),
    );
  }
}

class WDockItem {
  const WDockItem({
    required this.icon,
    this.onTap,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active; // copper-filled "current" cell
  final Color? color; // icon tint when not active
}

/// Capsule control dock (watch-style bottom bar).
class WDock extends StatelessWidget {
  const WDock({super.key, required this.items, this.height = 30});
  final List<WDockItem> items;
  final double height; // watch units

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final h = height * u;
    return Container(
      height: h,
      padding: EdgeInsets.all(3 * u),
      decoration: BoxDecoration(
        color: const Color(0xEB120D0B),
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(color: C.line, width: 1),
      ),
      child: Row(
        children: [
          for (final it in items) Expanded(child: _DockCell(item: it)),
        ],
      ),
    );
  }
}

class _DockCell extends StatefulWidget {
  const _DockCell({required this.item});
  final WDockItem item;

  @override
  State<_DockCell> createState() => _DockCellState();
}

class _DockCellState extends State<_DockCell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final u = context.u;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: it.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: it.onTap,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            color: it.active ? C.copper : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Icon(
            it.icon,
            size: 15 * u,
            color: it.active ? C.onCopper : (it.color ?? C.cream),
          ),
        ),
      ),
    );
  }
}

/// Small sliding on/off switch (replaces the Material Switch).
class WToggle extends StatelessWidget {
  const WToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34 * u,
        height: 18 * u,
        padding: EdgeInsets.all(2 * u),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? C.copper : C.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: value ? C.copper : C.line, width: 1),
        ),
        child: Container(
          width: 13 * u,
          height: 13 * u,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? C.onCopper : C.dim,
          ),
        ),
      ),
    );
  }
}
