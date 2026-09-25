import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app_theme.dart';

/// A frosted glass surface: blurred backdrop + translucent fill + a hairline
/// border. This is the base building block almost every screen in the app
/// sits on top of.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppRadius.lg,
    this.onTap,
    this.onLongPress,
    this.strong = false,
    this.margin,
    this.blurred = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// A slightly more opaque fill for surfaces that need to read clearly
  /// over a busy part of the animated background (e.g. the app bar).
  final bool strong;

  /// BackdropFilter is a real GPU cost, and it compounds badly when many
  /// cards are on screen at once (a scrolling list of them, each running
  /// its own blur pass, is enough to crash on weaker GPUs). Set this false
  /// for anything that repeats — list rows, skeleton loaders — and leave
  /// it true for one-off surfaces (nav bar, headers, dialogs) where the
  /// blur actually matters and there's only ever one on screen.
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: strong ? AppColors.glassSurfaceStrong : (blurred ? AppColors.glassSurface : AppColors.glassSurfaceStrong),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: AppColors.accentViolet.withOpacity(0.12),
        highlightColor: AppColors.accentViolet.withOpacity(0.06),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blurred ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: content) : content,
      ),
    );
  }
}

/// The app's primary call-to-action: a gradient-filled pill button with a
/// soft glow. Used sparingly — one per screen, for the thing you actually
/// want the user to do ("Continue with GitHub", "Commit Changes").
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient = AppColors.primaryGradient,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient gradient;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(color: gradient.colors.first.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          else ...[
            if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 10)],
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

/// A small translucent pill — used for filters ("All", "Private",
/// "Recently updated") and status tags (language, visibility).
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 6 : 9),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : AppColors.glassSurface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? Colors.transparent : AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: dense ? 12.5 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder shape for loading states — see spec's request
/// for skeleton loading rather than bare spinners on list screens.
class GlassSkeleton extends StatelessWidget {
  const GlassSkeleton({super.key, this.height = 16, this.width, this.borderRadius = AppRadius.sm});

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.glassSurface,
      highlightColor: AppColors.glassSurfaceStrong,
      period: const Duration(milliseconds: 1400),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A GlassCard-shaped skeleton, for list screens where each row is itself
/// a card (repo list, commit list, etc.) — keeps loading and loaded states
/// visually consistent instead of a plain shimmer block.
class GlassCardSkeleton extends StatelessWidget {
  const GlassCardSkeleton({super.key, this.height = 84});
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      blurred: false, // several of these render at once while loading — see the note on GlassCard.blurred
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            const GlassSkeleton(height: 40, width: 40, borderRadius: AppRadius.sm),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  GlassSkeleton(height: 14, width: 160),
                  SizedBox(height: 10),
                  GlassSkeleton(height: 11, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
