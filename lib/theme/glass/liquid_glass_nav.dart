import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../app_theme.dart';

class LiquidGlassNavItem {
  const LiquidGlassNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// A floating, frosted-glass pill navigation bar with a spring-animated
/// active capsule that slides between destinations. Built as a standalone,
/// reusable widget: everything it needs (items, selected index, callback)
/// comes in through the constructor, nothing here reaches into app state.
class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<LiquidGlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _capsuleController;

  @override
  void initState() {
    super.initState();
    // The controller's value IS the capsule's position, in "item slots"
    // (0 = first item's slot, 1 = second, ...) rather than a normalized
    // 0..1 progress — a real SpringSimulation drives it below, so this
    // never runs a fixed-duration tween.
    _capsuleController = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: (widget.items.length - 1).toDouble(),
      value: widget.selectedIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _settleTo(widget.selectedIndex.toDouble());
    }
  }

  void _settleTo(double target) {
    // Tuned for a quick, confident settle with only the faintest
    // overshoot — "spring-like... no excessive bouncing" per the brief.
    const spring = SpringDescription(mass: 0.9, stiffness: 420, damping: 30);
    final simulation = SpringSimulation(spring, _capsuleController.value, target, 0);
    _capsuleController.animateWith(simulation);
  }

  @override
  void dispose() {
    _capsuleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / widget.items.length;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Container(
              // A gradient "border" rather than a flat one: brighter at the
              // top, fading out — the thin glass highlight the brief asks
              // for, made by padding a gradient-filled outer box down to a
              // ~1px ring around the actual glass fill inside.
              padding: const EdgeInsets.all(1.1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.05)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill - 1),
                child: Container(
                  height: 64,
                  // Deliberately much lower opacity than a typical GlassCard
                  // — this is meant to read as barely-there glass, not a
                  // grey panel, with the app's own background gradient
                  // still visible through it.
                  color: Colors.white.withOpacity(0.045),
                  child: Stack(
                    children: [
                      // Diagonal light/reflection variation — brighter
                      // top-left, fading to nothing — so the surface reads
                      // as glass catching light rather than a flat tint.
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0x14FFFFFF), Color(0x05FFFFFF), Colors.transparent],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _capsuleController,
                          builder: (context, _) {
                            final left = _capsuleController.value * itemWidth;
                            return Positioned(
                              left: left + 6,
                              top: 7,
                              bottom: 7,
                              width: itemWidth - 12,
                              child: const _ActiveCapsule(),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: List.generate(widget.items.length, (i) {
                          final isSelected = i == widget.selectedIndex;
                          return Expanded(
                            child: _NavItemButton(
                              item: widget.items[i],
                              isSelected: isSelected,
                              onTap: () => widget.onSelected(i),
                            ),
                          );
                        }),
                      ),
                    ],
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

/// The floating highlight behind the selected item — styled to read as its
/// own separate piece of glass (gradient fill + inner top highlight sliver
/// + soft glow) rather than a flat color block.
class _ActiveCapsule extends StatelessWidget {
  const _ActiveCapsule();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accentViolet.withOpacity(0.62), AppColors.accentBlue.withOpacity(0.50)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.26), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentViolet.withOpacity(0.38),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          top: 2,
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItemButton extends StatelessWidget {
  const _NavItemButton({required this.item, required this.isSelected, required this.onTap});

  final LiquidGlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const _curve = Curves.easeOutCubic;
  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashColor: Colors.white.withOpacity(0.06),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSlide(
              offset: isSelected ? const Offset(0, -0.08) : Offset.zero,
              duration: _duration,
              curve: _curve,
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 0.90,
                duration: _duration,
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: _duration,
                  curve: _curve,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.white.withOpacity(0.45), blurRadius: 10, spreadRadius: -2)]
                        : [],
                  ),
                  child: Icon(item.icon, size: 22, color: color),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: _duration,
              curve: _curve,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
