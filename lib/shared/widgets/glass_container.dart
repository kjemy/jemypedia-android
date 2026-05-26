import 'package:flutter/material.dart';
import 'dart:ui';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.opacity = 0.1,
    this.color,
    this.borderRadius = 20,
    this.customBorderRadius,
    this.padding,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = customBorderRadius ?? BorderRadius.circular(borderRadius);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (color ?? (isDark ? Colors.white : Colors.black)).withOpacity(opacity),
              borderRadius: radius,
              border: Border.all(
                color: (borderColor ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
