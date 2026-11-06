import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The whole UI is drawn on a 200 x 235 "watch unit" canvas — the same aspect
/// as the 240 x 282 reference face — and scaled to the real screen.
const double kDesignW = 200;
const double kDesignH = 235;

extension WatchScale on BuildContext {
  /// One watch unit in logical pixels (fits both width and height).
  double get u {
    final s = MediaQuery.sizeOf(this);
    final byW = s.width / kDesignW;
    final byH = s.height / kDesignH;
    return math.min(byW, byH).clamp(0.6, 2.4).toDouble();
  }

  /// Font size in watch units, never below a legible 9 logical px.
  double fs(double v) => math.max(9.0, v * u);
}

/// "FRI" / "11/06" — the little date header from the reference watch face.
class WatchStamp {
  WatchStamp._();

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  static String day([DateTime? t]) => _days[(t ?? DateTime.now()).weekday - 1];

  static String date([DateTime? t]) {
    final d = t ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$m/$dd';
  }
}
