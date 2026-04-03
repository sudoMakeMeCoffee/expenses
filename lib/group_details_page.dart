import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/group_service.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Color groupColor;
  final String groupInitial;

  const GroupDetailsPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupColor,
    required this.groupInitial,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  String _groupName = '';
  List<Map<String, dynamic>> _members = [];
  String _createdBy = '';
  bool _isLoading = true;
  bool _isSavingName = false;

  late TextEditingController _nameController;
  bool _editingName = false;

  // For adding new members
  final _emailController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isCreator => _createdBy == _myUid;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _nameController = TextEditingController(text: widget.groupName);

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

    _loadGroupDetails();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── Load group details ─────────────────────────────────
  Future<void> _loadGroupDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      final memberUids = List<String>.from(data['members'] ?? []);
      _createdBy = data['createdBy'] as String? ?? '';

      final members = await GroupService.getMembers(memberUids);

      if (mounted) {
        setState(() {
          _groupName = data['name'] as String? ?? widget.groupName;
          _nameController.text = _groupName;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save group name ────────────────────────────────────
  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _groupName) {
      setState(() => _editingName = false);
      return;
    }

    setState(() => _isSavingName = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'name': newName});

      if (mounted) {
        setState(() {
          _groupName = newName;
          _editingName = false;
          _isSavingName = false;
        });
        _showSnack('Group name updated!', isError: false);
        // Tell the chat page to refresh its title
        Navigator.pop(context, {'action': 'renamed', 'name': newName});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingName = false);
        _showSnack('Failed to update name', isError: true);
      }
    }
  }

  // ── Search user by email ───────────────────────────────
  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundUser = null;
    });

    final user = await GroupService.searchUserByEmail(email);

    if (!mounted) return;
    setState(() => _isSearching = false);

    if (user == null) {
      setState(() => _searchError = 'No user found with that email.');
      return;
    }

    // Already a member?
    if (_members.any((m) => m['uid'] == user['uid'])) {
      setState(() => _searchError = 'This user is already in the group.');
      return;
    }

    setState(() {
      _foundUser = user;
      _searchError = null;
    });
  }

  // ── Add member ─────────────────────────────────────────
  Future<void> _addMember() async {
    if (_foundUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'members': FieldValue.arrayUnion([_foundUser!['uid']]),
      });

      if (mounted) {
        setState(() {
          _members.add(_foundUser!);
          _foundUser = null;
          _emailController.clear();
        });
        _showSnack('Member added!', isError: false);
      }
    } catch (e) {
      _showSnack('Failed to add member', isError: true);
    }
  }

  // ── Remove member ──────────────────────────────────────
  Future<void> _removeMember(Map<String, dynamic> member) async {
    final uid = member['uid'] as String;

    // Can't remove creator
    if (uid == _createdBy) {
      _showSnack('Cannot remove the group creator', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog(
      title: 'Remove Member',
      message: 'Remove ${member['name']} from this group?',
      confirmLabel: 'Remove',
      isDanger: true,
    );
    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'members': FieldValue.arrayRemove([uid]),
      });

      if (mounted) {
        setState(() => _members.removeWhere((m) => m['uid'] == uid));
        _showSnack('Member removed', isError: false);
      }
    } catch (e) {
      _showSnack('Failed to remove member', isError: true);
    }
  }

  // ── Leave group ────────────────────────────────────────
  Future<void> _leaveGroup() async {
    final confirm = await _showConfirmDialog(
      title: 'Leave Group',
      message: 'Are you sure you want to leave "${_groupName}"?',
      confirmLabel: 'Leave',
      isDanger: true,
    );
    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'members': FieldValue.arrayRemove([_myUid]),
      });

      if (mounted) {
        Navigator.pop(context); // close details
        Navigator.pop(context); // close chat
        Navigator.pop(context); // back to groups list
        _showSnack('You left the group', isError: false);
      }
    } catch (e) {
      _showSnack('Failed to leave group', isError: true);
    }
  }

  // ── Delete group ───────────────────────────────────────
  Future<void> _deleteGroup() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Group',
      message:
          'This will permanently delete "${_groupName}" and all messages. This cannot be undone.',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (!confirm) return;

    try {
      // Delete all messages first
      final messages = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId));
      await batch.commit();

      if (mounted) {
        // Pop all the way back to groups list
        Navigator.of(context).popUntil((route) {
          return route.settings.name == '/' ||
              route.isFirst;
        });
        _showSnack('Group deleted', isError: false);
      }
    } catch (e) {
      _showSnack('Failed to delete group', isError: true);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF8FAFC),
            )),
        content: Text(message,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white.withOpacity(0.4),
                )),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDanger
                    ? const Color(0xFFE24B4A).withOpacity(0.15)
                    : _indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDanger
                      ? const Color(0xFFE24B4A).withOpacity(0.4)
                      : _indigo.withOpacity(0.4),
                ),
              ),
              child: Text(confirmLabel,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDanger
                        ? const Color(0xFFF09595)
                        : const Color(0xFF818CF8),
                  )),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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

  // ── Color from name hash ───────────────────────────────
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B),
      const Color(0xFF5DCAA5),
    ];
    return colors[name.hashCode.abs() % colors.length];
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
                          const Text('Group Details',
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

                  const SizedBox(height: 16),

                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: _indigo.withOpacity(0.7),
                              strokeWidth: 2,
                            ),
                          )
                        : SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Group avatar + name ───────
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 72, height: 72,
                                        decoration: BoxDecoration(
                                          color: widget.groupColor
                                              .withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: widget.groupColor
                                                  .withOpacity(0.35),
                                              width: 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _groupName.isNotEmpty
                                                ? _groupName[0].toUpperCase()
                                                : 'G',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: widget.groupColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Editable group name
                                      if (_editingName) ...[
                                        Row(children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _nameController,
                                              autofocus: true,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFF8FAFC),
                                              ),
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.04),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10),
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
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: _isSavingName
                                                ? null
                                                : _saveName,
                                            child: Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                color: _indigo.withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                border: Border.all(
                                                    color: _indigo
                                                        .withOpacity(0.3)),
                                              ),
                                              child: _isSavingName
                                                  ? const Padding(
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      child:
                                                          CircularProgressIndicator(
                                                              color: Color(
                                                                  0xFF818CF8),
                                                              strokeWidth: 2))
                                                  : const Icon(
                                                      Icons.check_rounded,
                                                      color: Color(0xFF818CF8),
                                                      size: 18),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => setState(() {
                                              _editingName = false;
                                              _nameController.text = _groupName;
                                            }),
                                            child: Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.04),
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.08)),
                                              ),
                                              child: Icon(Icons.close_rounded,
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  size: 18),
                                            ),
                                          ),
                                        ]),
                                      ] else ...[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(_groupName,
                                                style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFF8FAFC),
                                                )),
                                            if (_isCreator) ...[
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => setState(
                                                    () => _editingName = true),
                                                child: Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: Colors.white
                                                        .withOpacity(0.35)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],

                                      const SizedBox(height: 4),
                                      Text(
                                        '${_members.length} member${_members.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // ── Add members section ───────
                                _SectionLabel('ADD MEMBERS'),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onSubmitted: (_) => _searchUser(),
                                      style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          color: Color(0xFFF8FAFC)),
                                      decoration: _fieldDeco(
                                        hint: 'Search by email...',
                                        icon: Icons.email_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: _isSearching ? null : _searchUser,
                                    child: Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        color: _indigo.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: _indigo.withOpacity(0.35)),
                                      ),
                                      child: _isSearching
                                          ? Padding(
                                              padding: const EdgeInsets.all(13),
                                              child: CircularProgressIndicator(
                                                  color: _indigo, strokeWidth: 2),
                                            )
                                          : const Icon(
                                              Icons.person_search_outlined,
                                              color: Color(0xFF818CF8), size: 18),
                                    ),
                                  ),
                                ]),

                                // Search error
                                if (_searchError != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF09595)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFF09595)
                                              .withOpacity(0.2)),
                                    ),
                                    child: Text(_searchError!,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 11,
                                          color: const Color(0xFFF09595)
                                              .withOpacity(0.8),
                                        )),
                                  ),
                                ],

                                // Found user preview
                                if (_foundUser != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5DCAA5)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color: const Color(0xFF5DCAA5)
                                              .withOpacity(0.25)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          color: _indigo.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _indigo.withOpacity(0.3)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (_foundUser!['name'] as String? ??
                                                        '?')
                                                    .isNotEmpty
                                                ? (_foundUser!['name']
                                                        as String)[0]
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
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _foundUser!['name'] as String? ??
                                                  '',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFFF8FAFC),
                                              ),
                                            ),
                                            Text(
                                              _foundUser!['email'] as String? ??
                                                  '',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 11,
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _foundUser = null),
                                        child: Icon(Icons.close_rounded,
                                            size: 16,
                                            color:
                                                Colors.white.withOpacity(0.3)),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _addMember,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF5DCAA5)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: const Color(0xFF5DCAA5)
                                                    .withOpacity(0.35)),
                                          ),
                                          child: const Text('Add',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF5DCAA5),
                                              )),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ],

                                const SizedBox(height: 24),

                                // ── Members list ──────────────
                                _SectionLabel(
                                    'MEMBERS (${_members.length})'),
                                const SizedBox(height: 10),
                                ..._members.map((member) {
                                  final uid = member['uid'] as String;
                                  final name =
                                      member['name'] as String? ?? 'Unknown';
                                  final email =
                                      member['email'] as String? ?? '';
                                  final isCreator = uid == _createdBy;
                                  final isMe = uid == _myUid;
                                  final color = _avatarColor(name);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.07)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: color.withOpacity(0.3)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: color,
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
                                            Row(children: [
                                              Text(
                                                isMe ? '$name (You)' : name,
                                                style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFFF8FAFC),
                                                ),
                                              ),
                                              if (isCreator) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _indigo
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: _indigo
                                                            .withOpacity(0.3)),
                                                  ),
                                                  child: const Text('Admin',
                                                      style: TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 9,
                                                        color:
                                                            Color(0xFF818CF8),
                                                      )),
                                                ),
                                              ],
                                            ]),
                                            Text(email,
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                )),
                                          ],
                                        ),
                                      ),
                                      // Remove button (only creator can remove, can't remove self or other creator)
                                      if (_isCreator && !isMe && !isCreator)
                                        GestureDetector(
                                          onTap: () => _removeMember(member),
                                          child: Container(
                                            width: 30, height: 30,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE24B4A)
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE24B4A)
                                                          .withOpacity(0.2)),
                                            ),
                                            child: const Icon(
                                                Icons.person_remove_outlined,
                                                size: 14,
                                                color: Color(0xFFF09595)),
                                          ),
                                        ),
                                    ]),
                                  );
                                }),

                                const SizedBox(height: 24),

                                // ── Danger zone ───────────────
                                _SectionLabel('ACTIONS'),
                                const SizedBox(height: 10),

                                // Leave group (non-creator only)
                                if (!_isCreator)
                                  _DangerButton(
                                    label: 'Leave Group',
                                    icon: Icons.logout_rounded,
                                    onTap: _leaveGroup,
                                  ),

                                if (!_isCreator) const SizedBox(height: 10),

                                // Delete group (creator only)
                                if (_isCreator)
                                  _DangerButton(
                                    label: 'Delete Group',
                                    icon: Icons.delete_outline_rounded,
                                    onTap: _deleteGroup,
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
          ? Icon(icon, size: 16, color: Colors.white.withOpacity(0.28))
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

// ── Section Label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 10,
        letterSpacing: 0.9,
        color: Colors.white.withOpacity(0.32),
      ));
}

// ── Danger Button ───────────────────────────────────────────────────────────

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE24B4A).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFE24B4A).withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: const Color(0xFFF09595).withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFF09595).withOpacity(0.8),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Shared Helpers ──────────────────────────────────────────────────────────

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
            gradient:
                RadialGradient(colors: [color, Colors.transparent]),
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