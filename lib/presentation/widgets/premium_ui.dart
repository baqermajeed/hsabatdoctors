import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.auroraTop,
            AppColors.auroraMid,
            AppColors.auroraBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _Blob(
              size: 280,
              color: AppColors.tealBright.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: _Blob(
              size: 240,
              color: AppColors.champagne.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            top: 180,
            left: 120,
            child: _Blob(
              size: 160,
              color: AppColors.teal.withValues(alpha: 0.08),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, offset: Offset.zero),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.white.withValues(alpha: 0.78),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              if (glow)
                BoxShadow(
                  color: AppColors.tealBright.withValues(alpha: 0.12),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Layered “3D” icon tile with depth shadow + gloss highlight.
class Icon3D extends StatelessWidget {
  const Icon3D({
    super.key,
    required this.icon,
    this.size = 52,
    this.colors = const [Color(0xFF14B8A6), Color(0xFF0F766E)],
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final double size;
  final List<Color> colors;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 3,
            top: 6,
            child: Container(
              width: size - 4,
              height: size - 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                color: colors.last.withValues(alpha: 0.35),
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: size * 0.28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(icon, color: iconColor, size: size * 0.46),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class HoverLiftCard extends StatefulWidget {
  const HoverLiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 22,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<HoverLiftCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.035 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.12 : 0.06),
                blurRadius: _hovered ? 28 : 16,
                offset: Offset(0, _hovered ? 16 : 8),
              ),
              BoxShadow(
                color: AppColors.tealBright.withValues(alpha: _hovered ? 0.18 : 0.0),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.busy,
  });

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = busy ? AppColors.champagne : AppColors.emerald;
    final bg = busy ? AppColors.champagneSoft : AppColors.emeraldSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            busy ? Icons.hourglass_top_rounded : Icons.verified_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon3D(
            icon: icon!,
            size: 46,
            colors: const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.colors = const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Row(
        children: [
          Icon3D(icon: icon, size: 48, colors: colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 8),
                        child: Text(
                          value,
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Color> doctorGradient(String name) {
  final palette = <List<Color>>[
    const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
    const [Color(0xFF38BDF8), Color(0xFF0369A1)],
    const [Color(0xFFFBBF24), Color(0xFFB45309)],
    const [Color(0xFFFB7185), Color(0xFFBE123C)],
    const [Color(0xFFA3E635), Color(0xFF4D7C0F)],
    const [Color(0xFF67E8F9), Color(0xFF0E7490)],
  ];
  final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return palette[hash % palette.length];
}
