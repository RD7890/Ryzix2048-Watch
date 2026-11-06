import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'sound.dart';
import 'store.dart';
import 'theme.dart';
import 'watch.dart';
import 'widgets/modals.dart';
import 'widgets/planet_backdrop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await RyzixStore.I.init();
  await Sfx.I.init();
  Sfx.I.enabled = RyzixStore.I.sfxEnabled;
  runApp(const RyzixApp());
}

class RyzixApp extends StatelessWidget {
  const RyzixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2048',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _AppShell(),
    );
  }
}

/// The "watch viewport".
///
/// * On a real watch (shortest side < 300 dp) the app fills the whole screen.
/// * On a phone / tablet it is previewed inside a watch-shaped frame with the
///   same 200:235 aspect as the reference face, so what you see on the phone is
///   exactly what the watch renders (everything scales by one unit, `context.u`).
///
/// A MediaQuery override hands every screen and dialog the viewport size.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RyzixStore.I.flushNow();
    super.dispose();
  }

  /// Commit the live board the moment the app leaves the foreground, so an
  /// OOM kill or swipe-away still resumes the unfinished game.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) RyzixStore.I.flushNow();
  }

  /// A context that lives INSIDE the nested navigator, so dialogs open within
  /// the watch viewport instead of covering the whole phone screen.
  BuildContext? get _dialogContext =>
      _navKey.currentState?.overlay?.context ?? _navKey.currentContext;

  /// Hardware back: navigate inside the app shell (like navigateBack() on the
  /// web) instead of closing the app. On the home screen ask to exit.
  Future<void> _handleBack() async {
    final nav = _navKey.currentState;
    if (nav == null) return;

    // Anything deeper than home -> just go back.
    if (nav.canPop() && !_isHomeTop) {
      Sfx.I.click();
      nav.pop();
      return;
    }

    // Home screen (or the root route) -> confirm exit.
    final ctx = _dialogContext;
    if (ctx == null) return;
    final leave = await confirmDialog(
      ctx,
      title: 'Exit Ryzix 2048?',
      message: 'Your progress is saved. Do you want to close the app?',
      confirmLabel: 'EXIT',
      icon: Icons.logout_rounded,
    );
    if (leave) {
      RyzixStore.I.flushNow();
      await SystemNavigator.pop();
    }
  }

  bool _isHomeTop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: C.shell,
        body: LayoutBuilder(
          builder: (context, box) {
            final mq = MediaQuery.of(context);
            final isWatch = mq.size.shortestSide < 300;

            Size vp;
            if (isWatch) {
              vp = Size(box.maxWidth, box.maxHeight);
            } else {
              var w = math.min(box.maxWidth * 0.92, 340.0);
              var h = w * kDesignH / kDesignW;
              final maxH = box.maxHeight * 0.94;
              if (h > maxH) {
                h = maxH;
                w = h * kDesignW / kDesignH;
              }
              vp = Size(w, h);
            }

            final screen = MediaQuery(
              data: mq.copyWith(
                size: vp,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: SizedBox(
                width: vp.width,
                height: vp.height,
                child: Stack(
                  children: [
                    const Positioned.fill(child: PlanetBackdrop()),
                    Positioned.fill(
                      child: Navigator(
                        key: _navKey,
                        observers: [
                          _TopRouteObserver(
                              (name) => _isHomeTop = name == 'home'),
                        ],
                        onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => const LoadingScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (isWatch) return screen;

            final radius = vp.width * 0.16;
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: C.black,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: const Color(0xFF2A211C), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33E37C48), blurRadius: 36),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 3),
                  child: screen,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tracks the name of the top-most route inside the app shell navigator.
class _TopRouteObserver extends NavigatorObserver {
  _TopRouteObserver(this.onTop);
  final void Function(String? name) onTop;

  @override
  void didPush(Route route, Route? previousRoute) =>
      onTop(route.settings.name);

  @override
  void didPop(Route route, Route? previousRoute) =>
      onTop(previousRoute?.settings.name);

  @override
  void didRemove(Route route, Route? previousRoute) =>
      onTop(previousRoute?.settings.name);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) =>
      onTop(newRoute?.settings.name);
}
