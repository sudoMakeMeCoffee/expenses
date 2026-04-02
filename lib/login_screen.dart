import 'dart:math';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF8B5CF6);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Firebase Login ─────────────────────────────────────
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService.login(
      email: email,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showSnack(error, isError: true);
      }
      // ✅ No navigation needed — AuthWrapper handles it automatically
    }
  }

  // ── Forgot Password ────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnack('Enter your email first', isError: true);
      return;
    }

    try {
      await AuthService.sendPasswordReset(email: email);
      if (mounted) {
        _showSnack('Reset link sent to $email', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to send reset email', isError: true);
      }
    }
  }

  // ── Snackbar helper ────────────────────────────────────
  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: isError
            ? const Color(0xFF6366F1).withOpacity(0.9)
            : const Color(0xFF1D9E75),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Animated orbs ──────────────────────────────
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, _) {
              final t = _orbController.value;
              return Stack(children: [
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t,
                    size: 300, color: _indigo.withOpacity(0.28)),
                _Orb(
                    x: MediaQuery.of(context).size.width - 190 - 20 * t,
                    y: MediaQuery.of(context).size.height - 280 + 28 * t,
                    size: 240, color: _purple.withOpacity(0.18)),
                _Orb(x: -30 + 28 * t,
                    y: MediaQuery.of(context).size.height - 380 - 20 * t,
                    size: 180,
                    color: const Color(0xFF14B8A6).withOpacity(0.14)),
              ]);
            },
          ),

          CustomPaint(size: Size.infinite, painter: _GridPainter()),

          // ── Content ────────────────────────────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),

                      _AvatarBadge(controller: _orbController),
                      const SizedBox(height: 20),

                      Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: _indigo.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your spending, own your money.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFFF8FAFC).withOpacity(0.38),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Email ──────────────────────────
                      _FieldLabel(label: 'Email address'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _emailController,
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 14),

                      // ── Password ───────────────────────
                      _FieldLabel(label: 'Password'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _passwordController,
                        hint: '••••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Forgot password ────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: _indigo.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Login button ───────────────────
                      _GradientButton(
                        label: 'Continue',
                        isLoading: _isLoading,
                        colors: [_indigo, _violet, _purple],
                        onTap: _login,
                      ),

                      const SizedBox(height: 24),

                      // ── Divider ────────────────────────
                      Row(children: [
                        Expanded(child: Container(height: 1,
                            color: Colors.white.withOpacity(0.07))),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1,
                            color: Colors.white.withOpacity(0.07))),
                      ]),

                      const SizedBox(height: 16),

                      // ── Social buttons ─────────────────
                      Row(children: [
                        Expanded(child: _SocialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _SocialButton(
                            label: 'Apple',
                            icon: Icons.apple_rounded)),
                      ]),

                      const SizedBox(height: 24),

                      // ── Sign up link ───────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No account yet?',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/register'),
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.only(left: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: const Text(
                              'Create one',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({required this.x, required this.y,
      required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x, top: y,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _AvatarBadge extends StatelessWidget {
  final AnimationController controller;
  const _AvatarBadge({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final glow = 0.05 + 0.1 * controller.value;
        return Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1).withOpacity(0.2),
                const Color(0xFFEC4899).withOpacity(0.12),
              ],
            ),
            border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                width: 1),
            boxShadow: [BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(glow),
              blurRadius: 20, spreadRadius: 4,
            )],
          ),
          child: const Icon(Icons.person_outline_rounded,
              color: Color(0xFF818CF8), size: 30),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          letterSpacing: 0.9,
          color: Colors.white.withOpacity(0.35),
        ),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 14,
        color: Color(0xFFF8FAFC),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          color: Colors.white.withOpacity(0.28),
        ),
        prefixIcon: Icon(icon,
            size: 18, color: Colors.white.withOpacity(0.3)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.09), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFF6366F1), width: 1.2),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final List<Color> colors;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.colors,
    required this.onTap,
  });
  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SocialButton({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}