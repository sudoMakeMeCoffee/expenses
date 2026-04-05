import 'dart:math';
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final Widget nextScreen;
  const LoadingScreen({super.key, required this.nextScreen});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _orbController;

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _pulseAnim;

  String _statusText = 'Syncing your data...';

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _pink = Color(0xFFEC4899);
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController.addListener(() {
      final v = _progressController.value;
      if (v > 0.30 && v < 0.32) {
        setState(() => _statusText = 'Loading categories...');
      } else if (v > 0.70 && v < 0.72) {
        setState(() => _statusText = 'Almost there...');
      }
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => widget.nextScreen,
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Ambient orbs ──────────────────────────────────────
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, _) {
              final t = _orbController.value;
              return Stack(children: [
                _Orb(
                  x: -60 + 30 * t,
                  y: -80 + 40 * t,
                  size: 280,
                  color: _indigo.withOpacity(0.25),
                ),
                _Orb(
                  x: MediaQuery.of(context).size.width - 180 - 20 * t,
                  y: MediaQuery.of(context).size.height - 300 + 25 * t,
                  size: 240,
                  color: _pink.withOpacity(0.15),
                ),
                _Orb(
                  x: -20 + 35 * t,
                  y: MediaQuery.of(context).size.height - 400 - 20 * t,
                  size: 180,
                  color: const Color(0xFF14B8A6).withOpacity(0.15),
                ),
              ]);
            },
          ),

          // ── Subtle grid ───────────────────────────────────────
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(),
          ),

          // ── Main content ──────────────────────────────────────
          AnimatedBuilder(
            animation: _fadeAnim,
            builder: (_, child) => Opacity(
              opacity: _fadeAnim.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: child,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon badge
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _indigo.withOpacity(0.25),
                              _pink.withOpacity(0.15),
                            ],
                          ),
                          border: Border.all(
                            color: _indigo.withOpacity(0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _indigo.withOpacity(0.15),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(child: _AppIcon()),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Label
                    Text(
                      'PERSONAL FINANCE',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: _indigo.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Title
                    const Text(
                      'Expenses',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Color(0xFFF8FAFC),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Track smarter, spend better.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFFF8FAFC).withOpacity(0.4),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 52),

                    // Progress section
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (_, _) {
                        final pct =
                            (_progressController.value * 100).round();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _statusText,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    color: const Color(0xFFF8FAFC)
                                        .withOpacity(0.35),
                                  ),
                                ),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 11,
                                    color: _indigo.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: _progressController.value,
                                minHeight: 4,
                                backgroundColor:
                                    Colors.white.withOpacity(0.07),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_indigo),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Dot indicators
                    _DotIndicator(controller: _pulseController),
                  ],
                ),
              ),
            ),
          ),

          // ── Version tag ───────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0, right: 0,
            child: Text(
              'v2.4.1',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                letterSpacing: 1.2,
                color: const Color(0xFFF8FAFC).withOpacity(0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({required this.x, required this.y, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x, top: y,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();
  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    const purple = Color(0xFFA855F7);
    const pink = Color(0xFFEC4899);
    return SizedBox(
      width: 32, height: 32,
      child: Column(
        children: [
          Row(children: [
            _Tile(color: indigo.withOpacity(0.9)),
            const SizedBox(width: 4),
            _Tile(color: purple.withOpacity(0.65)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _Tile(color: purple.withOpacity(0.65)),
            const SizedBox(width: 4),
            _Tile(color: pink.withOpacity(0.85)),
          ]),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Color color;
  const _Tile({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final AnimationController controller;
  const _DotIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final raw = (controller.value - delay) % 1.0;
            final t = raw < 0 ? raw + 1.0 : raw;
            final pulse = sin(t * pi);
            final opacity = 0.25 + 0.65 * pulse;
            final scale = 1.0 + 0.3 * pulse;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6366F1).withOpacity(opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}