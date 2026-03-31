import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

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
    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * 3 + 1,
      speedX: (_random.nextDouble() - 0.5) * 0.002,
      speedY: -(_random.nextDouble() * 0.003 + 0.001), // Float upward (antigravity)
      opacity: _random.nextDouble() * 0.5 + 0.1,
      color: [
        AppTheme.accentIndigo,
        AppTheme.accentViolet,
        AppTheme.accentCyan,
        AppTheme.accentPink,
      ][_random.nextInt(4)],
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
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Update particle positions
            for (var p in _particles) {
              p.x += p.speedX;
              p.y += p.speedY;

              // Wrap around
              if (p.y < -0.05) {
                p.y = 1.05;
                p.x = _random.nextDouble();
              }
              if (p.x < -0.05) p.x = 1.05;
              if (p.x > 1.05) p.x = -0.05;
            }
            return CustomPaint(
              painter: ParticlePainter(_particles),
              size: Size.infinite,
            );
          },
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

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.color,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
