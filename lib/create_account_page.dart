import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});
  @override
  State<CreateAccountPage> createState() =>
      _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  String _selectedType = '';
  bool _isLoading = false;

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF8B5CF6);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  final List<Map<String, dynamic>> _accountTypes = [
    {
      'type': 'Family',
      'icon': Icons.family_restroom_rounded,
      'color': Color(0xFF14B8A6),
      'desc': 'Track expenses with your family',
    },
    {
      'type': 'Group',
      'icon': Icons.group_outlined,
      'color': Color(0xFFEC4899),
      'desc': 'Split costs with friends',
    },
    {
      'type': 'Business',
      'icon': Icons.business_center_outlined,
      'color': Color(0xFFF59E0B),
      'desc': 'Manage business expenses',
    },
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this, duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnim = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
          parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter an account name',
          isError: true);
      return;
    }

    if (_selectedType.isEmpty) {
      _showSnack('Please select an account type',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get color for selected type
      final typeData = _accountTypes.firstWhere(
          (t) => t['type'] == _selectedType);
      final color = typeData['color'] as Color;
      final colorHex =
          '0x${color.value.toRadixString(16).toUpperCase().padLeft(8, '0')}';

      // In CreateAccountPage when saving to Firestore, make sure members is set:
await FirebaseFirestore.instance.collection('accounts').add({
  'userId': user.uid,
  'name': name,
  'type': _selectedType,
  'color': colorHex,
  'members': [user.uid], // ← add this line if missing
  'createdAt': FieldValue.serverTimestamp(),
});
      if (mounted) {
        _showSnack('Account created successfully!',
            isError: false);
        Navigator.pop(context, true); // return true = refresh
      }
    } catch (e) {
      debugPrint('Error creating account: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Failed to create account', isError: true);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Outfit')),
      backgroundColor: isError
          ? const Color(0xFF6366F1).withOpacity(0.9)
          : const Color(0xFF1D9E75),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
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
                _Orb(
                    x: -70 + 30 * t,
                    y: -90 + 40 * t,
                    size: 300,
                    color: _indigo.withOpacity(0.22)),
                _Orb(
                    x: w - 160 - 20 * t,
                    y: h - 260 + 26 * t,
                    size: 220,
                    color: _purple.withOpacity(0.14)),
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
                        Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('EXPENSES',
                                  style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 8,
                                    letterSpacing: 2.5,
                                    color:
                                        _indigo.withOpacity(0.6),
                                  )),
                              const Text('New Account',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: Color(0xFFF8FAFC),
                                  )),
                            ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          18, 0, 18, 24),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ── Solo info card ─────────
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF6366F1)
                                      .withOpacity(0.2)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1)
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF818CF8)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Personal (Solo)',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color:
                                            Color(0xFFF8FAFC),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Your default account — already active',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 11,
                                        color: Colors.white
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF14B8A6)
                                          .withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          const Color(0xFF14B8A6)
                                              .withOpacity(0.3)),
                                ),
                                child: const Text('Active',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 10,
                                      color: Color(0xFF14B8A6),
                                    )),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 24),

                          // ── Account name ───────────
                          _FieldLabel(label: 'Account Name'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Color(0xFFF8FAFC)),
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. Family, Work Trip...',
                              hintStyle: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: Colors.white
                                      .withOpacity(0.25)),
                              prefixIcon: Icon(
                                  Icons
                                      .drive_file_rename_outline_rounded,
                                  size: 17,
                                  color: Colors.white
                                      .withOpacity(0.28)),
                              filled: true,
                              fillColor:
                                  Colors.white.withOpacity(0.04),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white
                                        .withOpacity(0.09)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Account type ───────────
                          _FieldLabel(label: 'Account Type'),
                          const SizedBox(height: 12),

                          ..._accountTypes.map((t) {
                            final isSelected =
                                _selectedType == t['type'];
                            final color = t['color'] as Color;
                            return GestureDetector(
                              onTap: () => setState(() =>
                                  _selectedType =
                                      t['type'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 200),
                                margin: const EdgeInsets.only(
                                    bottom: 10),
                                padding: const EdgeInsets.all(
                                    14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.12)
                                      : Colors.white
                                          .withOpacity(0.03),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? color.withOpacity(0.4)
                                        : Colors.white
                                            .withOpacity(0.07),
                                    width:
                                        isSelected ? 1.2 : 1,
                                  ),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: color
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(
                                              12),
                                      border: Border.all(
                                          color: color
                                              .withOpacity(
                                                  0.25)),
                                    ),
                                    child: Icon(
                                        t['icon'] as IconData,
                                        size: 20,
                                        color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          t['type'] as String,
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: isSelected
                                                ? color
                                                : const Color(
                                                    0xFFF8FAFC),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t['desc'] as String,
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 11,
                                            color: Colors.white
                                                .withOpacity(
                                                    0.38),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 200),
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? color
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? color
                                            : Colors.white
                                                .withOpacity(
                                                    0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 12,
                                            color: Colors.white)
                                        : null,
                                  ),
                                ]),
                              ),
                            );
                          }),

                          const SizedBox(height: 24),

                          // ── Create button ──────────
                          _GradientButton(
                            label: 'Create Account',
                            isLoading: _isLoading,
                            colors: [_indigo, _violet, _purple],
                            onTap: _createAccount,
                          ),
                        ],
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

// ── Field Label ────────────────────────────────────────────────────────────

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

// ── Gradient Button ────────────────────────────────────────────────────────

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
          width: double.infinity, height: 50,
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
                        color: Colors.white, strokeWidth: 2))
                : Text(widget.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    )),
          ),
        ),
      ),
    );
  }
}

// ── Shared Helpers ─────────────────────────────────────────────────────────

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