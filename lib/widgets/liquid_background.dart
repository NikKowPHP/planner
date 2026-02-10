import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'dart:math';

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark Base
        Container(color: const Color(0xFF0F0F0F)),
        
        // Blobs
        Positioned(
          top: -100,
          left: -50,
          child: _AnimatedBlob(
             color: const Color(0xFF8E2DE2).withOpacity(0.4),
             size: 400,
          ),
        ),
         Positioned(
          top: 200,
          right: -100,
          child: _AnimatedBlob(
             color: const Color(0xFF4A00E0).withOpacity(0.4),
             size: 350,
             duration: const Duration(seconds: 10),
          ),
        ),
         Positioned(
          bottom: -50,
          left: 50,
           child: _AnimatedBlob(
             color: const Color(0xFF00C6FB).withOpacity(0.3),
             size: 300,
             duration: const Duration(seconds: 12),
          ),
        ),

        // Noise Overlay (Optional for grit, but maybe skip for pure sleekness)
        // keeping it clean for "liquid glass"
      ],
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _AnimatedBlob({
    required this.color,
    required this.size,
    this.duration = const Duration(seconds: 8),
  });

  @override
  Widget build(BuildContext context) {
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 2 * pi),
      duration: duration,
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value,
          child: Transform.translate(
            offset: Offset(sin(value) * 30, cos(value) * 30),
             child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color,
                    color.withOpacity(0),
                  ],
                ),
                boxShadow: [
                   BoxShadow(
                    color: color,
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ]
              ),
            ),
          ),
        );
      },
    );
  }
}
