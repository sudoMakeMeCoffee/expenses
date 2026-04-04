import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/location_service.dart';

class LocationRequestsPage extends StatefulWidget {
  const LocationRequestsPage({super.key});

  @override
  State<LocationRequestsPage> createState() => _LocationRequestsPageState();
}

class _LocationRequestsPageState extends State<LocationRequestsPage>
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
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
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

  Future<void> _accept(String requestId, String fromUid,
      String fromName) async {
    final success =
        await LocationService.acceptRequest(requestId, fromUid, fromName);
    if (mounted) {
      _showSnack(success
          ? '✅ Accepted! ${fromName} can now see your location.'
          : 'Failed to accept', isError: !success);
    }
  }

  Future<void> _decline(String requestId) async {
    final success = await LocationService.declineRequest(requestId);
    if (mounted) {
      _showSnack(
          success ? 'Request declined' : 'Failed to decline',
          isError: !success);
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

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
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
                    color: _indigo.withOpacity(0.18)),
                _Orb(x: w - 160 - 20 * t, y: h - 260 + 26 * t, size: 220,
                    color: _purple.withOpacity(0.12)),
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
                          Text('LOCATION',
                              style: TextStyle(fontFamily: 'SpaceMono',
                                  fontSize: 8, letterSpacing: 2.5,
                                  color: _indigo.withOpacity(0.6))),
                          const Text('Location Requests',
                              style: TextStyle(fontFamily: 'Outfit',
                                  fontSize: 20, fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Color(0xFFF8FAFC))),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Incoming requests ─────────
                          _Label('INCOMING REQUESTS'),
                          const SizedBox(height: 10),
                          StreamBuilder<QuerySnapshot>(
                            stream: LocationService.getIncomingRequests(),
                            builder: (context, snapshot) {
                              final requests = snapshot.data?.docs ?? [];
                              if (requests.isEmpty) {
                                return _EmptyCard(
                                    icon: Icons.inbox_outlined,
                                    message: 'No incoming requests');
                              }
                              return Column(
                                children: requests.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final fromName =
                                      data['fromName'] as String? ?? 'Unknown';
                                  final fromEmail =
                                      data['fromEmail'] as String? ?? '';
                                  final fromUid =
                                      data['fromUid'] as String? ?? '';
                                  final createdAt = data['createdAt'];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1)
                                          .withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFF6366F1)
                                              .withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(
                                            width: 38, height: 38,
                                            decoration: BoxDecoration(
                                              color: _indigo.withOpacity(0.15),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color:
                                                      _indigo.withOpacity(0.3)),
                                            ),
                                            child: Center(
                                              child: Text(
                                                fromName.isNotEmpty
                                                    ? fromName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF818CF8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(fromName,
                                                    style: const TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFFF8FAFC))),
                                                Text(fromEmail,
                                                    style: TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 11,
                                                        color: Colors.white
                                                            .withOpacity(0.4))),
                                              ],
                                            ),
                                          ),
                                          Text(_formatTime(createdAt),
                                              style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 10,
                                                  color: Colors.white
                                                      .withOpacity(0.3))),
                                        ]),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${fromName} wants to track your location',
                                          style: TextStyle(fontFamily: 'Outfit',
                                              fontSize: 12,
                                              color:
                                                  Colors.white.withOpacity(0.5)),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _decline(doc.id),
                                              child: Container(
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE24B4A)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: const Color(
                                                              0xFFE24B4A)
                                                          .withOpacity(0.25)),
                                                ),
                                                child: const Center(
                                                  child: Text('Decline',
                                                      style: TextStyle(
                                                          fontFamily: 'Outfit',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color(
                                                              0xFFF09595))),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: GestureDetector(
                                              onTap: () => _accept(
                                                  doc.id, fromUid, fromName),
                                              child: Container(
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF5DCAA5)
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: const Color(
                                                              0xFF5DCAA5)
                                                          .withOpacity(0.3)),
                                                ),
                                                child: const Center(
                                                  child: Text('Accept',
                                                      style: TextStyle(
                                                          fontFamily: 'Outfit',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF5DCAA5))),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Outgoing requests ─────────
                          _Label('SENT REQUESTS'),
                          const SizedBox(height: 10),
                          StreamBuilder<QuerySnapshot>(
                            stream: LocationService.getOutgoingRequests(),
                            builder: (context, snapshot) {
                              final requests = snapshot.data?.docs ?? [];
                              if (requests.isEmpty) {
                                return _EmptyCard(
                                    icon: Icons.send_outlined,
                                    message: 'No pending sent requests');
                              }
                              return Column(
                                children: requests.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final toEmail =
                                      data['toEmail'] as String? ?? '';
                                  final createdAt = data['createdAt'];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.07)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF59E0B),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(toEmail,
                                            style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                color: Color(0xFFF8FAFC))),
                                      ),
                                      Text(
                                        'Pending • ${_formatTime(createdAt)}',
                                        style: TextStyle(fontFamily: 'Outfit',
                                            fontSize: 10,
                                            color: const Color(0xFFF59E0B)
                                                .withOpacity(0.7)),
                                      ),
                                    ]),
                                  );
                                }).toList(),
                              );
                            },
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

// ── Helpers ────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontFamily: 'Outfit', fontSize: 10, letterSpacing: 0.9,
          color: Colors.white.withOpacity(0.32)));
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(children: [
        Icon(icon, size: 26, color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(fontFamily: 'Outfit', fontSize: 12,
            color: Colors.white.withOpacity(0.3))),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({required this.x, required this.y,
      required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Positioned(
        left: x, top: y,
        child: Container(width: size, height: size,
            decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [color, Colors.transparent]))));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.022)..strokeWidth = 0.5;
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