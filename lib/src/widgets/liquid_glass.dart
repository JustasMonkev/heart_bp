import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/liquid_theme.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LiquidTheme.canvasTop, LiquidTheme.canvasBottom],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: -160, right: -80, child: _Orb(color: Color(0xFFFFB0A8), size: 420)),
          const Positioned(top: 240, left: -140, child: _Orb(color: Color(0xFFB4CDF6), size: 320)),
          const Positioned(bottom: -120, right: -40, child: _Orb(color: Color(0xFFFFD4A0), size: 360)),
          const Positioned(bottom: 120, left: 10, child: _Orb(color: Color(0xFFE0C6FF), size: 260)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(22),
    this.opacity = 0.55,
    this.blur = 28,
    this.stroke = true,
    this.shadow = true,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final double blur;
  final bool stroke;
  final bool shadow;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final topTint = (tint ?? Colors.white).withValues(alpha: (opacity + 0.18).clamp(0.0, 1.0));
    final bottomTint = (tint ?? Colors.white).withValues(alpha: (opacity - 0.05).clamp(0.0, 1.0));

    final panel = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topTint, bottomTint],
            ),
            border: stroke
                ? Border.all(color: LiquidTheme.glassStroke, width: 0.8)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha: 0.35),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              borderRadius: br,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );

    if (!shadow) return panel;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: LiquidTheme.glassShadow,
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: panel,
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final vertical = dense ? 14.0 : 18.0;
    final radius = 22.0;

    if (primary) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: disabled
                ? const LinearGradient(colors: [Color(0xFFCFCFD2), Color(0xFFB5B5BA)])
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [LiquidTheme.accent, LiquidTheme.accentGlow],
                  ),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: LiquidTheme.accent.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 19),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GlassSurface(
      radius: radius,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
      opacity: disabled ? 0.35 : 0.55,
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: disabled ? LiquidTheme.inkFaint : LiquidTheme.ink,
              size: 19,
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              color: disabled ? LiquidTheme.inkFaint : LiquidTheme.ink,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.leading,
    this.accent,
    this.onTap,
  });

  final String label;
  final Widget? leading;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? LiquidTheme.ink;
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      opacity: 0.48,
      blur: 18,
      shadow: false,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 74,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (subtitle != null)
                      Text(subtitle!.toUpperCase(), style: LiquidTheme.eyebrow),
                    Text(title, style: LiquidTheme.titleL),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidBackButton extends StatelessWidget {
  const LiquidBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 18,
      padding: const EdgeInsets.all(10),
      opacity: 0.5,
      blur: 24,
      shadow: false,
      onTap: () => Navigator.of(context).maybePop(),
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: LiquidTheme.ink),
    );
  }
}

class LiquidIconAction extends StatelessWidget {
  const LiquidIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 18,
      padding: const EdgeInsets.all(10),
      opacity: 0.5,
      blur: 24,
      shadow: false,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 20,
        child: busy
            ? const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(LiquidTheme.ink),
              )
            : Icon(icon, size: 18, color: onPressed == null ? LiquidTheme.inkFaint : LiquidTheme.ink),
      ),
    );
  }
}
