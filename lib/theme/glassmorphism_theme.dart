import 'package:flutter/material.dart';
import 'dart:ui';

/// Apple-inspired glassmorphism theme for iOS 17 / visionOS style
class GlassTheme {
  // Background colors - Deep navy/charcoal
  static const Color bgPrimary = Color(0xFF0D1421);
  static const Color bgSecondary = Color(0xFF141B2D);
  static const Color bgTertiary = Color(0xFF1A2235);
  
  // Glass card colors
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassHighlight = Color(0x0DFFFFFF);
  
  // Accent colors - Mint, Cyan, Amber (soft, not neon)
  static const Color accentMint = Color(0xFF4ADE80);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentAmber = Color(0xFFFBBF24);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentBlue = Color(0xFF3B82F6);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF6B7280);
  
  // Status colors
  static const Color statusGood = Color(0xFF4ADE80);
  static const Color statusWarning = Color(0xFFFBBF24);
  static const Color statusActive = Color(0xFF22D3EE);
  
  // Blur values
  static const double blurLight = 10.0;
  static const double blurMedium = 20.0;
  static const double blurHeavy = 30.0;
  
  // Border radius
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;
  
  // Glassmorphism card decoration
  static BoxDecoration glassCard({
    double blur = blurMedium,
    double opacity = 0.08,
    double borderOpacity = 0.1,
    double radius = radiusMedium,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: Color.fromRGBO(255, 255, 255, opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Color.fromRGBO(255, 255, 255, borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: -5,
          ),
      ],
    );
  }
  
  // Status badge decoration
  static BoxDecoration statusBadge(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(radiusSmall),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    );
  }
  
  // Gradient for ambient background
  static LinearGradient ambientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bgPrimary,
      const Color(0xFF0F172A),
      const Color(0xFF1E1B4B).withOpacity(0.3),
      bgPrimary,
    ],
    stops: const [0.0, 0.3, 0.7, 1.0],
  );
  
  // Text styles
  static TextStyle get headerTitle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: textSecondary,
  );
  
  static TextStyle get cardTitle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: textPrimary,
  );
  
  static TextStyle get bodyText => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  
  static TextStyle get statValue => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  
  static TextStyle get statLabel => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: textMuted,
  );
}

/// Reusable glass card widget with backdrop blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double radius;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = GlassTheme.blurMedium,
    this.opacity = 0.08,
    this.borderOpacity = 0.1,
    this.radius = GlassTheme.radiusMedium,
    this.glowColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: GlassTheme.glassCard(
              blur: blur,
              opacity: opacity,
              borderOpacity: borderOpacity,
              radius: radius,
              glowColor: glowColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Ambient background with floating orbs
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: GlassTheme.ambientGradient,
      ),
      child: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -100,
            left: -50,
            child: _buildOrb(200, GlassTheme.accentCyan.withOpacity(0.1)),
          ),
          Positioned(
            top: 300,
            right: -80,
            child: _buildOrb(250, GlassTheme.accentPurple.withOpacity(0.08)),
          ),
          Positioned(
            bottom: 100,
            left: 50,
            child: _buildOrb(180, GlassTheme.accentAmber.withOpacity(0.06)),
          ),
          // Noise overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.02,
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

/// Status badge pill
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: GlassTheme.statusBadge(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar with gradient fill
class GlassProgressBar extends StatelessWidget {
  final double progress;
  final Color startColor;
  final Color endColor;
  final double height;

  const GlassProgressBar({
    super.key,
    required this.progress,
    this.startColor = GlassTheme.accentMint,
    this.endColor = GlassTheme.accentCyan,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
            ),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: endColor.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
