import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/expense_service.dart';
import 'services/account_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with TickerProviderStateMixin {
  String _filterType = 'All';   // All / Expense / Income
  String _filterAccount = 'All';
  List<Map<String, dynamic>> _allEntries = [];
  Map<String, String> _accountNames = {};
  bool _isLoading = true;

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  // Category → icon/color maps
  static const _expenseIcons = {
    'Electricity': Icons.bolt_outlined,
    'Water Bill':  Icons.water_drop_outlined,
    'Food':        Icons.restaurant_outlined,
    'Transport':   Icons.directions_car_outlined,
    'Health':      Icons.favorite_border_rounded,
    'Shopping':    Icons.shopping_bag_outlined,
    'Education':   Icons.school_outlined,
    'Other':       Icons.more_horiz_rounded,
  };
  static const _expenseColors = {
    'Electricity': Color(0xFF818CF8),
    'Water Bill':  Color(0xFF5DCAA5),
    'Food':        Color(0xFFF59E0B),
    'Transport':   Color(0xFFEC4899),
    'Health':      Color(0xFFF09595),
    'Shopping':    Color(0xFFA855F7),
    'Education':   Color(0xFF14B8A6),
    'Other':       Color(0xFF888780),
  };
  static const _incomeIcons = {
    'Salary':    Icons.account_balance_wallet_outlined,
    'Freelance': Icons.laptop_outlined,
    'Business':  Icons.storefront_outlined,
    'Gift':      Icons.card_giftcard_outlined,
    'Interest':  Icons.trending_up_rounded,
    'Other':     Icons.more_horiz_rounded,
  };
  static const _incomeColors = {
    'Salary':    Color(0xFF5DCAA5),
    'Freelance': Color(0xFF818CF8),
    'Business':  Color(0xFFF59E0B),
    'Gift':      Color(0xFFEC4899),
    'Interest':  Color(0xFF14B8A6),
    'Other':     Color(0xFF888780),
  };

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
    _loadData();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load account names for display
      final accSnap = await AccountService.getAccounts().first;
      final accMap = <String, String>{};
      for (final doc in accSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        accMap[doc.id] = data['name'] as String? ?? 'Unknown';
      }

      // Load all expenses
      final expSnap = await ExpenseService.getExpenses().first;
      final entries = expSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'] as String? ?? 'expense';
        return {
          'id': doc.id,
          'type': type,
          'amount': amount,
          'category': data['category'] ?? 'Other',
          'payerName': data['payerName'] ?? '',
          'note': data['note'] ?? '',
          'accountId': data['accountId'] ?? '',
          'date': data['date'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      // Sort by date descending
      entries.sort((a, b) {
        final aTs = a['date'] as Timestamp?;
        final bTs = b['date'] as Timestamp?;
        if (aTs == null || bTs == null) return 0;
        return bTs.compareTo(aTs);
      });

      if (mounted) {
        setState(() {
          _accountNames = accMap;
          _allEntries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _allEntries.where((e) {
      final typeMatch = _filterType == 'All' ||
          e['type'] == _filterType.toLowerCase();
      final accMatch = _filterAccount == 'All' ||
          e['accountId'] == _filterAccount;
      return typeMatch && accMatch;
    }).toList();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = (ts as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      final s = amount.toInt().toString();
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. ${amount.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalIncome = filtered
        .where((e) => e['type'] == 'income')
        .fold(0.0, (s, e) => s + (e['amount'] as double));
    final totalExpense = filtered
        .where((e) => e['type'] == 'expense')
        .fold(0.0, (s, e) => s + (e['amount'] as double));

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
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t,
                    size: 300, color: _indigo.withOpacity(0.2)),
                _Orb(x: w - 160 - 20 * t, y: h - 260 + 26 * t,
                    size: 220, color: _purple.withOpacity(0.12)),
              ]);
            },
          ),
          CustomPaint(size: Size.infinite, painter: _GridPainter()),

          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, child) => Opacity(
                  opacity: _fadeAnim.value, child: child),
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
                              child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white54, size: 20),
                            ),
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('EXPENSES',
                              style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 8,
                                letterSpacing: 2.5,
                                color: _indigo.withOpacity(0.6),
                              )),
                          const Text('History',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Color(0xFFF8FAFC),
                              )),
                        ]),
                        // Refresh button
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isLoading = true);
                              _loadData();
                            },
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Icon(Icons.refresh_rounded,
                                  size: 18,
                                  color: Colors.white.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_isLoading)
                    Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _indigo.withOpacity(0.7),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        color: _indigo,
                        backgroundColor: const Color(0xFF1A1D27),
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Summary cards ──────────────
                              Row(children: [
                                Expanded(child: _SummaryCard(
                                  label: 'Total Income',
                                  value: _formatAmount(totalIncome),
                                  color: const Color(0xFF5DCAA5),
                                  icon: Icons.arrow_downward_rounded,
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _SummaryCard(
                                  label: 'Total Expense',
                                  value: _formatAmount(totalExpense),
                                  color: const Color(0xFFF09595),
                                  icon: Icons.arrow_upward_rounded,
                                )),
                              ]),

                              const SizedBox(height: 14),

                              // ── Type filter chips ───────────
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['All', 'Expense', 'Income']
                                      .map((t) {
                                    final active = _filterType == t;
                                    Color chipColor = _indigo;
                                    if (t == 'Expense') chipColor = const Color(0xFFF09595);
                                    if (t == 'Income') chipColor = const Color(0xFF5DCAA5);
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => setState(() => _filterType = t),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? chipColor.withOpacity(0.15)
                                                : Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: active
                                                  ? chipColor.withOpacity(0.45)
                                                  : Colors.white.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Text(t,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                color: active
                                                    ? chipColor
                                                    : Colors.white.withOpacity(0.4),
                                              )),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Entry count ─────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${filtered.length} ${filtered.length == 1 ? 'entry' : 'entries'}',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // ── Entries list ────────────────
                              filtered.isEmpty
                                  ? _EmptyState()
                                  : Column(
                                      children: filtered.map((entry) {
                                        return _HistoryItem(
                                          entry: entry,
                                          accountName: _accountNames[
                                                  entry['accountId']] ??
                                              'Unknown',
                                          formatDate: _formatDate,
                                          formatAmount: _formatAmount,
                                          expenseIcons: _expenseIcons,
                                          expenseColors: _expenseColors,
                                          incomeIcons: _incomeIcons,
                                          incomeColors: _incomeColors,
                                        );
                                      }).toList(),
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

// ── History Item ───────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String accountName;
  final String Function(dynamic) formatDate;
  final String Function(double) formatAmount;
  final Map<String, IconData> expenseIcons;
  final Map<String, Color> expenseColors;
  final Map<String, IconData> incomeIcons;
  final Map<String, Color> incomeColors;

  const _HistoryItem({
    required this.entry,
    required this.accountName,
    required this.formatDate,
    required this.formatAmount,
    required this.expenseIcons,
    required this.expenseColors,
    required this.incomeIcons,
    required this.incomeColors,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = entry['type'] == 'income';
    final category = entry['category'] as String;
    final amount = entry['amount'] as double;
    final payerName = entry['payerName'] as String;
    final note = entry['note'] as String;

    final color = isIncome
        ? (incomeColors[category] ?? const Color(0xFF5DCAA5))
        : (expenseColors[category] ?? const Color(0xFF888780));
    final icon = isIncome
        ? (incomeIcons[category] ?? Icons.more_horiz_rounded)
        : (expenseIcons[category] ?? Icons.more_horiz_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(category,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF8FAFC),
                              )),
                          Text(
                            '${isIncome ? '+' : '-'} ${formatAmount(amount)}',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isIncome
                                  ? const Color(0xFF5DCAA5)
                                  : const Color(0xFFF09595),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            // Type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isIncome
                                    ? const Color(0xFF5DCAA5).withOpacity(0.12)
                                    : const Color(0xFFF09595).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isIncome
                                      ? const Color(0xFF5DCAA5).withOpacity(0.3)
                                      : const Color(0xFFF09595).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                isIncome ? '↑ Income' : '↓ Expense',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 9,
                                  color: isIncome
                                      ? const Color(0xFF5DCAA5)
                                      : const Color(0xFFF09595),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Account name
                            Text(accountName,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.35),
                                )),
                          ]),
                          Text(formatDate(entry['date']),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.3),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Extra details row (payer/source + note)
          if (payerName.isNotEmpty || note.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (payerName.isNotEmpty)
                    Row(children: [
                      Icon(
                        isIncome
                            ? Icons.business_outlined
                            : Icons.person_outline_rounded,
                        size: 13,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isIncome
                            ? 'From: $payerName'
                            : 'Payer: $payerName',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ]),
                  if (payerName.isNotEmpty && note.isNotEmpty)
                    const SizedBox(height: 4),
                  if (note.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 13,
                            color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(note,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.45),
                              )),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
              )),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ]),
      ]),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.15)),
      ),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined,
            size: 32,
            color: const Color(0xFF818CF8).withOpacity(0.4)),
        const SizedBox(height: 8),
        Text('No entries yet',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Colors.white.withOpacity(0.35),
            )),
        const SizedBox(height: 4),
        Text('Add an expense or income to see history',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: const Color(0xFF818CF8).withOpacity(0.5),
            )),
      ]),
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────

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
          gradient: RadialGradient(colors: [color, Colors.transparent]),
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