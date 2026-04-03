import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'services/group_service.dart';
import 'create_group_page.dart';
import 'group_details_page.dart';

// ── Groups List Page ────────────────────────────────────────────────────────

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
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
    super.dispose();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }

  Color _groupColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GROUPS',
                                  style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 8,
                                    letterSpacing: 2.5,
                                    color: _indigo.withOpacity(0.6),
                                  )),
                              const Text('Messages',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: Color(0xFFF8FAFC),
                                  )),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateGroupPage()),
                          ),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                  color: _indigo.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.group_add_outlined,
                                size: 18, color: Color(0xFF818CF8)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Groups list ───────────────────────
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: GroupService.getUserGroups(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: _indigo.withOpacity(0.7),
                              strokeWidth: 2,
                            ),
                          );
                        }

                        final groups = snapshot.data?.docs ?? [];

                        if (groups.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color: Colors.white.withOpacity(0.1)),
                                const SizedBox(height: 12),
                                Text('No groups yet',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.3),
                                    )),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateGroupPage()),
                                  ),
                                  child: Text('Tap + to create one',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: _indigo.withOpacity(0.6),
                                      )),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: groups.length,
                          itemBuilder: (_, i) {
                            final data =
                                groups[i].data() as Map<String, dynamic>;
                            final groupId = groups[i].id;
                            final name = data['name'] as String? ?? 'Group';
                            final lastMsg =
                                data['lastMessage'] as String? ?? '';
                            final lastTime = data['lastMessageTime'];
                            final initial = name.isNotEmpty
                                ? name[0].toUpperCase()
                                : 'G';
                            final color = _groupColor(name);

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupChatPage(
                                    groupId: groupId,
                                    groupName: name,
                                    groupColor: color,
                                    groupInitial: initial,
                                  ),
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.07)),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: color.withOpacity(0.3)),
                                    ),
                                    child: Center(
                                      child: Text(initial,
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFF8FAFC),
                                            )),
                                        const SizedBox(height: 3),
                                        Text(
                                          lastMsg.isEmpty
                                              ? 'No messages yet'
                                              : lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12,
                                            color: Colors.white
                                                .withOpacity(0.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTime(lastTime),
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        );
                      },
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

// ── Group Chat Page ─────────────────────────────────────────────────────────

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Color groupColor;
  final String groupInitial;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupColor,
    required this.groupInitial,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  late String _currentGroupName;

  static const _indigo = Color(0xFF6366F1);
  static const _bg = Color(0xFF0F1117);

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _currentGroupName = widget.groupName;
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    FocusScope.of(context).unfocus(); // ← dismiss keyboard on send
    setState(() => _isSending = true);
    await GroupService.sendMessage(groupId: widget.groupId, text: text);
    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  // ── Fixed image send ───────────────────────────────────
  Future<void> _sendImage() async {
    try {
      final picker = ImagePicker();
      ImageSource? source;

      // ← use a variable to capture source, not return value
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1D27),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  source = ImageSource.gallery;
                  Navigator.pop(sheetCtx); // ← use sheetCtx not context
                },
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () {
                  source = ImageSource.camera;
                  Navigator.pop(sheetCtx); // ← use sheetCtx not context
                },
              ),
            ],
          ),
        ),
      );

      // Sheet is now fully closed before we proceed
      if (source == null || !mounted) return;

      final picked = await picker.pickImage(
        source: source!,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null || !mounted) return;

      setState(() => _isSending = true);
      await GroupService.sendImage(
        groupId: widget.groupId,
        imageFile: File(picked.path),
      );
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Image send error: $e');
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Open group details ─────────────────────────────────
  Future<void> _openDetails() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailsPage(
          groupId: widget.groupId,
          groupName: _currentGroupName,
          groupColor: widget.groupColor,
          groupInitial: _currentGroupName.isNotEmpty
              ? _currentGroupName[0].toUpperCase()
              : 'G',
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map) {
      if (result['action'] == 'renamed') {
        setState(() => _currentGroupName = result['name'] as String);
      } else if (result['action'] == 'deleted' ||
          result['action'] == 'left') {
        Navigator.pop(context);
      }
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  bool _isSameDay(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    try {
      final da = (a as Timestamp).toDate();
      final db = (b as Timestamp).toDate();
      return da.year == db.year &&
          da.month == db.month &&
          da.day == db.day;
    } catch (_) {
      return false;
    }
  }

  String _dayLabel(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) return 'Today';
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) return 'Yesterday';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // ← KEY FIX: pushes input bar up when keyboard opens
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _GridPainter()),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Row(children: [
                    GestureDetector(
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
                    const SizedBox(width: 12),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: widget.groupColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: widget.groupColor.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          _currentGroupName.isNotEmpty
                              ? _currentGroupName[0].toUpperCase()
                              : 'G',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.groupColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _openDetails,
                        child: Row(children: [
                          Flexible(
                            child: Text(
                              _currentGroupName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_right_rounded,
                              size: 16,
                              color: Colors.white.withOpacity(0.3)),
                        ]),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openDetails,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Icon(Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.45)),
                      ),
                    ),
                  ]),
                ),

                // ── Messages ─────────────────────────────
                Expanded(
                  child: GestureDetector(
                    // ← tap chat area to dismiss keyboard
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: GroupService.getMessages(widget.groupId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: _indigo.withOpacity(0.7),
                              strokeWidth: 2,
                            ),
                          );
                        }

                        final messages = snapshot.data?.docs ?? [];

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                                _scrollController
                                    .position.maxScrollExtent);
                          }
                        });

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 40,
                                    color: Colors.white.withOpacity(0.1)),
                                const SizedBox(height: 10),
                                Text('No messages yet',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.25),
                                    )),
                                Text('Say hello! 👋',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.15),
                                    )),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final data = messages[i].data()
                                as Map<String, dynamic>;
                            final isMe = data['senderId'] == _myUid;
                            final type =
                                data['type'] as String? ?? 'text';
                            final text = data['text'] as String? ?? '';
                            final imageUrl =
                                data['imageUrl'] as String?;
                            final senderName =
                                data['senderName'] as String? ?? '';
                            final time = data['createdAt'];

                            final showDivider = i == 0 ||
                                !_isSameDay(
                                  (messages[i - 1].data()
                                      as Map<String,
                                          dynamic>)['createdAt'],
                                  time,
                                );

                            return Column(
                              children: [
                                if (showDivider)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(children: [
                                      Expanded(
                                          child: Divider(
                                              color: Colors.white
                                                  .withOpacity(0.08))),
                                      Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10),
                                        child: Text(_dayLabel(time),
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 10,
                                              color: Colors.white
                                                  .withOpacity(0.25),
                                            )),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color: Colors.white
                                                  .withOpacity(0.08))),
                                    ]),
                                  ),
                                _MessageBubble(
                                  isMe: isMe,
                                  senderName: senderName,
                                  text: text,
                                  imageUrl: imageUrl,
                                  type: type,
                                  time: _formatTime(time),
                                  groupColor: widget.groupColor,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // ── Input bar ─────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151F),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.07))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Image button
                      GestureDetector(
                        onTap: _isSending ? null : _sendImage,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Icon(Icons.image_outlined,
                              size: 18,
                              color: Colors.white.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Text input
                      Expanded(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 120),
                          child: TextField(
                            controller: _msgController,
                            maxLines: null,
                            textCapitalization:
                                TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              color: Color(0xFFF8FAFC),
                            ),
                            onSubmitted: (_) => _sendText(),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.25),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                    color: _indigo.withOpacity(0.4),
                                    width: 1.2),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send button
                      GestureDetector(
                        onTap: _isSending ? null : _sendText,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _indigo.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Icon(Icons.send_rounded,
                                  size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String senderName;
  final String text;
  final String? imageUrl;
  final String type;
  final String time;
  final Color groupColor;

  const _MessageBubble({
    required this.isMe,
    required this.senderName,
    required this.text,
    required this.imageUrl,
    required this.type,
    required this.time,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: groupColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: groupColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty
                      ? senderName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: groupColor,
                  ),
                ),
              ),
            ),
          ],

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.68,
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(senderName,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          color: groupColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        )),
                  ),

                Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF6366F1).withOpacity(0.25)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF6366F1).withOpacity(0.35)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: type == 'image' && imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: Radius.circular(isMe ? 15 : 3),
                            bottomRight: Radius.circular(isMe ? 3 : 15),
                          ),
                          child: Image.network(
                            imageUrl!,
                            width: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 220, height: 160,
                                color: Colors.white.withOpacity(0.05),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: const Color(0xFF6366F1)
                                        .withOpacity(0.5),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          child: Text(text,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: Color(0xFFF8FAFC),
                                height: 1.4,
                              )),
                        ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(time,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.22),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source Tile ─────────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              )),
        ]),
      ),
    );
  }
}

// ── Shared Helpers ──────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb(
      {required this.x,
      required this.y,
      required this.size,
      required this.color});
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