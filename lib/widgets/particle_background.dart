import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Animated floating particle background with performance optimizations.
/// Uses RepaintBoundary to isolate animation from the child widget tree,
/// and caches Paint objects to avoid ~2400 allocations/sec.
class ParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;

  const ParticleBackground({
    super.key,
    required this.child,
    this.particleCount = 40,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
  }

  Particle _createParticle() {
    final color = const [
      AppTheme.accentIndigo,
      AppTheme.accentViolet,
      AppTheme.accentCyan,
      AppTheme.accentPink,
    ][_random.nextInt(4)];
    final opacity = _random.nextDouble() * 0.5 + 0.1;
    final size = _random.nextDouble() * 3 + 1;

    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: size,
      speedX: (_random.nextDouble() - 0.5) * 0.002,
      speedY: -(_random.nextDouble() * 0.003 + 0.001),
      opacity: opacity,
      color: color,
      // ⚡ Pre-create the Paint object — avoids 60 allocations/sec per particle
      paint: Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ⚡ RepaintBoundary isolates particle repaints from the child tree
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              for (var p in _particles) {
                p.x += p.speedX;
                p.y += p.speedY;

                if (p.y < -0.05) {
                  p.y = 1.05;
                  p.x = _random.nextDouble();
                }
                if (p.x < -0.05) p.x = 1.05;
                if (p.x > 1.05) p.x = -0.05;
              }
              return CustomPaint(
                painter: _ParticlePainter(_particles),
                size: Size.infinite,
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class Particle {
  double x, y;
  final double size;
  double speedX, speedY;
  final double opacity;
  final Color color;
  final Paint paint; // ⚡ Cached

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.color,
    required this.paint,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        p.paint, // ⚡ Use cached paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
