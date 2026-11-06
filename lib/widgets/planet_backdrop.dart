import 'package:flutter/material.dart';

/// Copper-marble planet — a pre-rendered image (assets/images/planet.jpg) so it
/// costs a single texture draw on a watch GPU instead of live shader work.
/// Lit limb on the right, black terminator on the left, like the reference
/// face. Screens push it back with [Scrim] wherever they need text contrast.
class PlanetBackdrop extends StatelessWidget {
  const PlanetBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Image(
            image: AssetImage('assets/images/planet.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

/// Black veil used by screens to push the planet back behind the UI.
class Scrim extends StatelessWidget {
  const Scrim(this.opacity, {super.key});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: ColoredBox(color: Colors.black.withOpacity(opacity)),
      ),
    );
  }
}
