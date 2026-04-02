import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChecked = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
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
      vsync: this, duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty ||
        password.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Please complete all fields', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters',
          isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    if (!_isChecked) {
      _showSnack('Please accept the Terms of Service',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService.register(
      name: name,
      email: email,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showSnack(error, isError: true);
      }
    }
  }

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
          // ── Orbs ──────────────────────────────────────
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              final t = _orbController.value;
              final w = MediaQuery.of(context).size.width;
              final h = MediaQuery.of(context).size.height;
              return Stack(children: [
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t,
                    size: 300,
                    color: _indigo.withOpacity(0.26)),
                _Orb(
                    x: w - 190 - 20 * t,
                    y: h - 280 + 28 * t,
                    size: 240,
                    color: _purple.withOpacity(0.16)),
                _Orb(
                    x: -30 + 28 * t,
                    y: h - 380 - 20 * t,
                    size: 180,
                    color: const Color(0xFF14B8A6)
                        .withOpacity(0.13)),
              ]);
            },
          ),

          CustomPaint(
              size: Size.infinite, painter: _GridPainter()),

          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child),
              ),
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 12, 20, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.05),
                                borderRadius:
                                    BorderRadius.circular(11),
                                border: Border.all(
                                    color: Colors.white
                                        .withOpacity(0.08)),
                              ),
                              child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white54,
                                  size: 20),
                            ),
                          ),
                        ),
                        Text(
                          'EXPENSES',
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            letterSpacing: 2.5,
                            color: _indigo.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.025),
                        borderRadius:
                            const BorderRadius.vertical(
                                top: Radius.circular(28)),
                        border: Border(
                          top: BorderSide(
                              color: Colors.white
                                  .withOpacity(0.07)),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            24, 24, 24, 32),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Create account',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: Color(0xFFF8FAFC),
                                )),
                            const SizedBox(height: 3),
                            Text(
                              'Start tracking in minutes.',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFFF8FAFC)
                                    .withOpacity(0.35),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ── Full name ──────────────
                            _FieldLabel(label: 'Full name'),
                            const SizedBox(height: 6),
                            _StyledField(
                              controller: _nameController,
                              hint: 'Jane Doe',
                              icon:
                                  Icons.person_outline_rounded,
                            ),

                            const SizedBox(height: 14),

                            // ── Email ──────────────────
                            _FieldLabel(
                                label: 'Email address'),
                            const SizedBox(height: 6),
                            _StyledField(
                              controller: _emailController,
                              hint: 'jane@example.com',
                              icon:
                                  Icons.mail_outline_rounded,
                              keyboardType:
                                  TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 14),

                            // ── Password ───────────────
                            _FieldLabel(label: 'Password'),
                            const SizedBox(height: 6),
                            _StyledField(
                              controller: _passwordController,
                              hint: '••••••••••',
                              icon:
                                  Icons.lock_outline_rounded,
                              obscure: _obscure,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons
                                          .visibility_off_outlined
                                      : Icons
                                          .visibility_outlined,
                                  size: 17,
                                  color: Colors.white
                                      .withOpacity(0.28),
                                ),
                                onPressed: () => setState(
                                    () =>
                                        _obscure = !_obscure),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── Confirm Password ───────
                            _FieldLabel(
                                label: 'Confirm password'),
                            const SizedBox(height: 6),
                            _StyledField(
                              controller:
                                  _confirmPasswordController,
                              hint: '••••••••••',
                              icon:
                                  Icons.lock_outline_rounded,
                              obscure: _obscureConfirm,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons
                                          .visibility_off_outlined
                                      : Icons
                                          .visibility_outlined,
                                  size: 17,
                                  color: Colors.white
                                      .withOpacity(0.28),
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm =
                                        !_obscureConfirm),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Terms checkbox ─────────
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _isChecked = !_isChecked),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 200),
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: _isChecked
                                          ? _indigo
                                              .withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(
                                              6),
                                      border: Border.all(
                                        color: _isChecked
                                            ? _indigo
                                                .withOpacity(
                                                    0.6)
                                            : Colors.white
                                                .withOpacity(
                                                    0.2),
                                      ),
                                    ),
                                    child: _isChecked
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Color(
                                                0xFF818CF8))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          height: 1.5,
                                          color: Colors.white
                                              .withOpacity(
                                                  0.35),
                                        ),
                                        children: const [
                                          TextSpan(
                                              text:
                                                  'I agree to the '),
                                          TextSpan(
                                            text:
                                                'Terms of Service',
                                            style: TextStyle(
                                                color: Color(
                                                    0xFF818CF8)),
                                          ),
                                          TextSpan(
                                              text: ' and '),
                                          TextSpan(
                                            text:
                                                'Privacy Policy',
                                            style: TextStyle(
                                                color: Color(
                                                    0xFF818CF8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Register button ────────
                            _GradientButton(
                              label: 'Create account',
                              isLoading: _isLoading,
                              colors: [
                                _indigo,
                                _violet,
                                _purple
                              ],
                              onTap: _register,
                            ),

                            const SizedBox(height: 18),

                            // ── Sign in link ───────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Colors.white
                                        .withOpacity(0.28),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                      padding:
                                          const EdgeInsets.only(
                                              left: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap),
                                  child: const Text('Sign in',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w500,
                                        color:
                                            Color(0xFF818CF8),
                                      )),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 10,
        letterSpacing: 0.9,
        color: Colors.white.withOpacity(0.32),
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
          fontSize: 13,
          color: Color(0xFFF8FAFC)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            color: Colors.white.withOpacity(0.28)),
        prefixIcon: Icon(icon,
            size: 17,
            color: Colors.white.withOpacity(0.28)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.09),
              width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
  State<_GradientButton> createState() =>
      _GradientButtonState();
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
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2))
                : Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}