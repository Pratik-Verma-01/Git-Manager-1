import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Wraps a screen with the app's signature background: a deep gradient
/// base plus a few soft, slowly-drifting blurred color blobs. One shared
/// AnimationController for the whole app (see [AuroraBackgroundScope])
/// keeps this to a single ticker rather than one per screen.
class AnimatedAuroraBackground extends StatelessWidget {
  const AnimatedAuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = AuroraBackgroundScope.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.backgroundBase, AppColors.backgroundIndigo, AppColors.backgroundViolet],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) => CustomPaint(painter: _AuroraPainter(t: progress.value)),
          ),
        ),
        child,
      ],
    );
  }
}

/// Owns the single shared AnimationController so every screen's background
/// animates in sync and Flutter only has one ticker running for it, not
/// one per route.
class AuroraBackgroundScope extends StatefulWidget {
  const AuroraBackgroundScope({super.key, required this.child});

  final Widget child;

  static Animation<double> of(BuildContext context) {
    final state = context.dependOnInheritedWidgetOfExactType<_AuroraInherited>();
    assert(state != null, 'AuroraBackgroundScope must wrap the app above any AnimatedAuroraBackground.');
    return state!.controller;
  }

  @override
  State<AuroraBackgroundScope> createState() => _AuroraBackgroundScopeState();
}

class _AuroraBackgroundScopeState extends State<AuroraBackgroundScope> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuroraInherited(controller: _controller, child: widget.child);
  }
}

class _AuroraInherited extends InheritedWidget {
  const _AuroraInherited({required this.controller, required super.child});
  final AnimationController controller;

  @override
  bool updateShouldNotify(_AuroraInherited oldWidget) => false; // the controller itself is the notifier
}

class _Blob {
  const _Blob({required this.color, required this.baseCenter, required this.radius, required this.phase, required this.speed});
  final Color color;
  final Offset baseCenter; // fractional position (0..1) within the canvas
  final double radius;
  final double phase;
  final double speed;
}

const _blobs = [
  _Blob(color: AppColors.accentViolet, baseCenter: Offset(0.22, 0.20), radius: 220, phase: 0, speed: 1.0),
  _Blob(color: AppColors.accentBlue, baseCenter: Offset(0.82, 0.30), radius: 260, phase: 2.1, speed: 0.8),
  _Blob(color: AppColors.accentPink, baseCenter: Offset(0.30, 0.82), radius: 200, phase: 4.2, speed: 1.15),
  _Blob(color: AppColors.accentCyan, baseCenter: Offset(0.78, 0.85), radius: 240, phase: 1.4, speed: 0.9),
];

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t});
  final double t; // 0..1, looping

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in _blobs) {
      final angle = (t * 2 * pi * blob.speed) + blob.phase;
      // A gentle 8%-of-size wander around each blob's base position, so
      // the motion reads as "drifting" rather than orbiting in a circle.
      final dx = size.width * 0.08 * sin(angle);
      final dy = size.height * 0.08 * cos(angle * 0.8);
      final center = Offset(size.width * blob.baseCenter.dx + dx, size.height * blob.baseCenter.dy + dy);

      // A multi-stop RadialGradient alone (no MaskFilter.blur) — the extra
      // stops give a soft-enough falloff to still read as a glowing blob,
      // without a real GPU blur pass recomputed every frame across a large
      // radius. That per-frame blur was heavy enough to crash low-end
      // devices when combined with the BackdropFilters elsewhere on
      // screen; a gradient is essentially free by comparison.
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withOpacity(0.30),
            blob.color.withOpacity(0.16),
            blob.color.withOpacity(0.05),
            blob.color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: blob.radius));

      canvas.drawCircle(center, blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}
