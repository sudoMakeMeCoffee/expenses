import 'package:flutter/material.dart';
import 'services/group_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  List<Map<String, dynamic>> _addedMembers = [];
  bool _isSearching = false;
  bool _isCreating = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser; // ← stores search result to confirm

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
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    debugPrint('🔍 Searching for email: "$email"');

    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundUser = null;
    });

    final user = await GroupService.searchUserByEmail(email);

    debugPrint('📦 Search result: $user');

    if (!mounted) return;
    setState(() => _isSearching = false);

    if (user == null) {
      debugPrint('❌ No user found for email: "$email"');
      setState(() => _searchError = 'No user found with that email.\nMake sure the email is registered.');
      return;
    }

    // Check if already added
    if (_addedMembers.any((m) => m['uid'] == user['uid'])) {
      setState(() => _searchError = 'This user is already added');
      return;
    }

    // Check if it's the current user themselves
    debugPrint('✅ Found user: ${user['name']} (${user['email']})');

    // Show the found user as a preview card to confirm before adding
    setState(() {
      _foundUser = user;
      _searchError = null;
    });
  }

  void _confirmAddUser() {
    if (_foundUser == null) return;
    setState(() {
      _addedMembers.add(_foundUser!);
      _foundUser = null;
      _emailController.clear();
    });
  }

  void _dismissFoundUser() {
    setState(() {
      _foundUser = null;
      _emailController.clear();
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter a group name', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    final memberUids = _addedMembers.map((m) => m['uid'] as String).toList();
    final groupId = await GroupService.createGroup(
      name: name,
      memberUids: memberUids,
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (groupId != null) {
      _showSnack('Group created!', isError: false);
      Navigator.pop(context, true);
    } else {
      _showSnack('Failed to create group', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
      backgroundColor: isError
          ? const Color(0xFF6366F1).withOpacity(0.9)
          : const Color(0xFF1D9E75),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              final t = _orbController.value;
              final w = MediaQuery.of(context).size.width;
              final h = MediaQuery.of(context).size.height;
              return Stack(children: [
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t, size: 300,
                    color: _indigo.withOpacity(0.22)),
                _Orb(x: w - 160 - 20 * t, y: h - 260 + 26 * t, size: 220,
                    color: _purple.withOpacity(0.14)),
              ]);
            },
          ),
          CustomPaint(size: Size.infinite, painter: _GridPainter()),

          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                    offset: Offset(0, _slideAnim.value), child: child),
              ),
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: const Icon(Icons.chevron_left_rounded,
                                  color: Colors.white54, size: 20),
                            ),
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('GROUPS',
                              style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 8,
                                letterSpacing: 2.5,
                                color: _indigo.withOpacity(0.6),
                              )),
                          const Text('Create Group',
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

                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Group name ────────────────
                          _Label('GROUP NAME'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: Color(0xFFF8FAFC)),
                            decoration: _fieldDeco(
                              hint: 'e.g. Family, Work Team...',
                              icon: Icons.group_outlined,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Search by email ───────────
                          _Label('ADD MEMBERS BY EMAIL'),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: Color(0xFFF8FAFC)),
                                onSubmitted: (_) => _searchUser(),
                                decoration: _fieldDeco(
                                  hint: 'Enter email address',
                                  icon: Icons.email_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _isSearching ? null : _searchUser,
                              child: Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: _indigo.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _indigo.withOpacity(0.35)),
                                ),
                                child: _isSearching
                                    ? Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: CircularProgressIndicator(
                                          color: _indigo, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.person_search_outlined,
                                        color: Color(0xFF818CF8), size: 20),
                              ),
                            ),
                          ]),

                          // ── Error message ─────────────
                          if (_searchError != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF09595).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFF09595).withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 14,
                                    color: const Color(0xFFF09595).withOpacity(0.7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_searchError!,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 11,
                                        color: const Color(0xFFF09595).withOpacity(0.8),
                                      )),
                                ),
                              ]),
                            ),
                          ],

                          // ── Found user preview ────────
                          if (_foundUser != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5DCAA5).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color: const Color(0xFF5DCAA5).withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 14,
                                        color: const Color(0xFF5DCAA5).withOpacity(0.8)),
                                    const SizedBox(width: 6),
                                    Text('User found!',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 11,
                                          color: const Color(0xFF5DCAA5).withOpacity(0.8),
                                        )),
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Container(
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                        color: _indigo.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _indigo.withOpacity(0.3)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (_foundUser!['name'] as String? ?? '?')
                                                  .isNotEmpty
                                              ? (_foundUser!['name'] as String)[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF818CF8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _foundUser!['name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFF8FAFC),
                                            ),
                                          ),
                                          Text(
                                            _foundUser!['email'] as String? ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _dismissFoundUser,
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                                color: Colors.white.withOpacity(0.08)),
                                          ),
                                          child: Center(
                                            child: Text('Cancel',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 12,
                                                  color: Colors.white.withOpacity(0.4),
                                                )),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        onTap: _confirmAddUser,
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF5DCAA5).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                                color: const Color(0xFF5DCAA5).withOpacity(0.35)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.person_add_outlined,
                                                  size: 14,
                                                  color: Color(0xFF5DCAA5)),
                                              const SizedBox(width: 6),
                                              const Text('Add to Group',
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF5DCAA5),
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ── Members list ──────────────
                          if (_addedMembers.isNotEmpty) ...[
                            _Label('MEMBERS (${_addedMembers.length})'),
                            const SizedBox(height: 10),
                            ..._addedMembers.map((member) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.07)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(
                                        color: _indigo.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _indigo.withOpacity(0.3)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (member['name'] as String? ?? '?')
                                                  .isNotEmpty
                                              ? (member['name'] as String)[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF818CF8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member['name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFF8FAFC),
                                            ),
                                          ),
                                          Text(
                                            member['email'] as String? ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.35),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _addedMembers.remove(member)),
                                      child: Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF09595).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFF09595).withOpacity(0.2)),
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            size: 14,
                                            color: Color(0xFFF09595)),
                                      ),
                                    ),
                                  ]),
                                )),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(children: [
                                Icon(Icons.group_add_outlined,
                                    size: 28,
                                    color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 8),
                                Text('No members added yet',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.3),
                                    )),
                                Text('Search by email above',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.2),
                                    )),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // ── Create button ─────────────
                          GestureDetector(
                            onTap: _isCreating ? null : _createGroup,
                            child: Container(
                              width: double.infinity, height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [_indigo, _violet, _purple],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _indigo.withOpacity(0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isCreating
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.group_add_outlined,
                                              size: 18, color: Colors.white),
                                          const SizedBox(width: 8),
                                          const Text('CREATE GROUP',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.0,
                                                color: Colors.white,
                                              )),
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
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 13,
          color: Colors.white.withOpacity(0.25)),
      prefixIcon: icon != null
          ? Icon(icon, size: 17, color: Colors.white.withOpacity(0.28))
          : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.white.withOpacity(0.09), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF6366F1), width: 1.2),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 10,
        letterSpacing: 0.9,
        color: Colors.white.withOpacity(0.32),
      ));
}

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({required this.x, required this.y,
      required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Positioned(
        left: x, top: y,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent]),
          ),
        ),
      );
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