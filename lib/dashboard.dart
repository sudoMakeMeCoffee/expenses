import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/expense_service.dart';
import 'services/user_service.dart';
import 'services/account_service.dart';
import 'add_expenses.dart';
import 'analysis.dart';
import 'history_page.dart';
import 'location_map_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  String _userName = '';
  String _userInitials = '';
  double _totalSpent = 0;
  double _totalIncome = 0;
  List<Map<String, dynamic>> _recentExpenses = [];
  bool _isLoading = true;

  // ── Account dropdown state ─────────────────────────────
  List<Map<String, dynamic>> _accounts = [];
  String _selectedAccountId = '';
  String _selectedAccountName = 'Solo';
  bool _accountsLoadingDropdown = true;

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
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Load all data ──────────────────────────────────────
  Future<void> _loadData() async {
    await _loadUserName();
    await _loadAccountsForDropdown();
    await _loadExpenses();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final data = await UserService.getUser(user.uid);
      if (data != null && mounted) {
        final name = data['name'] as String? ?? '';
        setState(() {
          _userName = name;
          final parts = name.trim().split(' ');
          _userInitials = parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : name.isNotEmpty
                  ? name[0].toUpperCase()
                  : '?';
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  // ── Load accounts for dropdown ─────────────────────────
  Future<void> _loadAccountsForDropdown() async {
    try {
      final snapshot = await AccountService.getAccounts().first;
      final accounts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'type': data['type'] ?? 'Solo',
        };
      }).toList();

      if (mounted) {
        // Default to Solo account
        final solo = accounts.firstWhere(
          (a) => a['type'] == 'Solo',
          orElse: () => accounts.isNotEmpty
              ? accounts.first
              : {'id': '', 'name': 'All', 'type': 'Solo'},
        );

        setState(() {
          _accounts = accounts;
          // Only update selection if not already set
          if (_selectedAccountId.isEmpty) {
            _selectedAccountId = solo['id'] as String;
            _selectedAccountName = solo['name'] as String;
          }
          _accountsLoadingDropdown = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts dropdown: $e');
      if (mounted) setState(() => _accountsLoadingDropdown = false);
    }
  }

  // ── Load expenses filtered by selected account ─────────
  Future<void> _loadExpenses() async {
    try {
      final snapshot = _selectedAccountId.isEmpty
          ? await ExpenseService.getMonthlyExpenses().first
          : await AccountService.getAccountMonthlyExpenses(
                  _selectedAccountId)
              .first;

      final docs = snapshot.docs;
      double spent = 0;
      double income = 0;
      List<Map<String, dynamic>> expenses = [];

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'] as String? ?? 'expense';

        if (type == 'expense') {
          spent += amount;
        } else {
          income += amount;
        }

        expenses.add({
          'id': doc.id,
          'name': data['category'] ?? 'Unknown',
          'date': _formatDate(data['date']),
          'account': data['accountId'] ?? '',
          'amount': type == 'expense' ? -amount : amount,
          'type': type,
          'note': data['note'] ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _totalSpent = spent;
          _totalIncome = income;
          _recentExpenses = expenses.take(4).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return 'Rs. ${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      final s = amount.toInt().toString();
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. ${amount.toInt()}';
  }

  void _navigate(Widget page, {bool reload = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) {
      if (reload) _loadData();
    });
  }

  // ── Account type icon ──────────────────────────────────
  IconData _accountIcon(String type) {
    switch (type) {
      case 'Family':
        return Icons.family_restroom_rounded;
      case 'Group':
        return Icons.group_outlined;
      case 'Business':
        return Icons.business_center_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _totalIncome - _totalSpent;
    final budgetPct = _totalIncome > 0
        ? (_totalSpent / _totalIncome).clamp(0.0, 1.0)
        : 0.0;

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

          CustomPaint(size: Size.infinite, painter: _GridPainter()),

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
                  // ── Top bar ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
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
                              _userInitials,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                              Text(
                                _userName.isEmpty
                                    ? 'Loading...'
                                    : _userName,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF8FAFC),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Account dropdown ──────────────────
                  if (!_accountsLoadingDropdown && _accounts.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAccountId.isEmpty
                                ? null
                                : _selectedAccountId,
                            icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.3),
                                size: 18),
                            dropdownColor: const Color(0xFF1A1D27),
                            isExpanded: true,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Color(0xFFF8FAFC)),
                            items: _accounts.map((acc) {
                              final type = acc['type'] as String;
                              return DropdownMenuItem<String>(
                                value: acc['id'] as String,
                                child: Row(children: [
                                  Icon(
                                    _accountIcon(type),
                                    size: 15,
                                    color: const Color(0xFF818CF8)
                                        .withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(acc['name'] as String,
                                      style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          color: Color(0xFFF8FAFC))),
                                  const SizedBox(width: 6),
                                  Text('· $type',
                                      style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 11,
                                          color: Colors.white
                                              .withOpacity(0.35))),
                                ]),
                              );
                            }).toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              final acc = _accounts
                                  .firstWhere((a) => a['id'] == id);
                              setState(() {
                                _selectedAccountId = id;
                                _selectedAccountName =
                                    acc['name'] as String;
                                _isLoading = true;
                              });
                              _loadExpenses();
                            },
                          ),
                        ),
                      ),
                    ),

                  // ── Account badge (single account) ────
                  if (!_accountsLoadingDropdown && _accounts.length == 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _indigo.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            Icon(_accountIcon(
                                _accounts.first['type'] as String),
                                size: 12,
                                color: const Color(0xFF818CF8)
                                    .withOpacity(0.7)),
                            const SizedBox(width: 5),
                            Text(
                              _accounts.first['name'] as String,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 4),

                  // ── Body ─────────────────────────────
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: _indigo.withOpacity(0.7),
                              strokeWidth: 2,
                            ),
                          )
                        : RefreshIndicator(
                            color: _indigo,
                            backgroundColor: const Color(0xFF1A1D27),
                            onRefresh: _loadData,
                            child: SingleChildScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // ── Stat cards ───────
                                  Row(children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: 'This Month Spending',
                                        value: _formatAmount(_totalSpent),
                                        sub: _totalIncome > 0
                                            ? (remaining >= 0
                                                ? '▼ ${_formatAmount(remaining)} left'
                                                : '▲ Over by ${_formatAmount(remaining.abs())}')
                                            : 'Add income to track',
                                        subColor: remaining >= 0
                                            ? const Color(0xFF5DCAA5)
                                            : const Color(0xFFF09595),
                                        valueColor:
                                            const Color(0xFFF8FAFC),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'This Month Income',
                                        value:
                                            _formatAmount(_totalIncome),
                                        sub: _totalIncome == 0
                                            ? 'Tap + to add income'
                                            : '${((remaining / _totalIncome) * 100).clamp(0, 100).toStringAsFixed(0)}% remaining',
                                        subColor: _totalIncome == 0
                                            ? const Color(0xFF818CF8)
                                                .withOpacity(0.5)
                                            : const Color(0xFF818CF8),
                                        valueColor:
                                            const Color(0xFF818CF8),
                                      ),
                                    ),
                                  ]),

                                  const SizedBox(height: 14),

                                  // ── Budget bar ────────
                                  Column(children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _totalIncome == 0
                                              ? 'No income added yet'
                                              : 'Spent vs Income',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 10,
                                            color: Colors.white
                                                .withOpacity(0.35),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _navigate(
                                            const AddExpensePage(),
                                            reload: true,
                                          ),
                                          child: Row(children: [
                                            Text(
                                              _totalIncome == 0
                                                  ? 'Add income +'
                                                  : '${(budgetPct * 100).toStringAsFixed(0)}% used',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 10,
                                                color: Color(0xFF818CF8),
                                              ),
                                            ),
                                            if (_totalIncome == 0) ...[
                                              const SizedBox(width: 3),
                                              const Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                size: 11,
                                                color: Color(0xFF818CF8),
                                              ),
                                            ],
                                          ]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100),
                                      child: LinearProgressIndicator(
                                        value: budgetPct,
                                        minHeight: 6,
                                        backgroundColor: Colors.white
                                            .withOpacity(0.07),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          budgetPct > 0.8
                                              ? const Color(0xFFF09595)
                                              : _indigo,
                                        ),
                                      ),
                                    ),
                                    if (_totalIncome > 0 ||
                                        _totalSpent > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [
                                            Container(
                                              width: 6, height: 6,
                                              decoration:
                                                  const BoxDecoration(
                                                color: Color(0xFF5DCAA5),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Income: ${_formatAmount(_totalIncome)}',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 10,
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ]),
                                          Row(children: [
                                            Container(
                                              width: 6, height: 6,
                                              decoration:
                                                  const BoxDecoration(
                                                color: Color(0xFFF09595),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Spent: ${_formatAmount(_totalSpent)}',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 10,
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ],
                                  ]),

                                  const SizedBox(height: 14),

                                  // ── Quick actions ─────
                                  Row(children: [
                                    Expanded(
                                      child: _QuickAction(
                                        icon: Icons.add_card_outlined,
                                        label: 'Add Expense',
                                        color: const Color(0xFF818CF8),
                                        onTap: () => _navigate(
                                          const AddExpensePage(),
                                          reload: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _QuickAction(
                                        icon: Icons.history_rounded,
                                        label: 'History',
                                        color: const Color(0xFF5DCAA5),
                                        onTap: () => _navigate(
                                            const HistoryPage()),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _QuickAction(
                                        icon: Icons.bar_chart_rounded,
                                        label: 'Analytics',
                                        color: const Color(0xFFEC4899),
                                        onTap: () => _navigate(
                                            const AnalysisPage()),
                                      ),
                                    ),
                                  ]),

                                  const SizedBox(height: 16),

                                  // ── Expense history ───
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Account name label
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Expense History',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFF8FAFC),
                                            ),
                                          ),
                                          if (_selectedAccountName
                                              .isNotEmpty)
                                            Text(
                                              _selectedAccountName,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 10,
                                                color: const Color(
                                                        0xFF818CF8)
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _navigate(const HistoryPage()),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                        ),
                                        child: const Text(
                                          'See all →',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12,
                                            color: Color(0xFF818CF8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  _recentExpenses.isEmpty
                                      ? _EmptyExpenses(
                                          onAdd: () => _navigate(
                                            const AddExpensePage(),
                                            reload: true,
                                          ),
                                        )
                                      : Column(
                                          children: _recentExpenses
                                              .map((e) =>
                                                  _ExpenseItem(expense: e))
                                              .toList(),
                                        ),

                                  const SizedBox(height: 16),

                                  // ── Loved ones card ───
                                  const Text(
                                    'Find Your Loved Ones',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF8FAFC),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _LovedOnesCard(
  onTap: () => _navigate(const LocationMapPage()),
),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // ── NO BottomNavBar here — handled by MainShell ──
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor, valueColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.valueColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
              )),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: valueColor,
              )),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: subColor,
              )),
        ],
      ),
    );
  }
}

// ── Quick Action ───────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: Colors.white.withOpacity(0.45),
              )),
        ]),
      ),
    );
  }
}

// ── Expense Item ───────────────────────────────────────────────────────────

class _ExpenseItem extends StatelessWidget {
  final Map<String, dynamic> expense;
  const _ExpenseItem({required this.expense});

  static const _categoryIcons = {
    'Electricity': Icons.bolt_outlined,
    'Water Bill': Icons.water_drop_outlined,
    'Food': Icons.restaurant_outlined,
    'Transport': Icons.directions_car_outlined,
    'Health': Icons.favorite_border_rounded,
    'Shopping': Icons.shopping_bag_outlined,
    'Education': Icons.school_outlined,
    'Salary': Icons.account_balance_wallet_outlined,
    'Freelance': Icons.laptop_outlined,
    'Business': Icons.storefront_outlined,
    'Gift': Icons.card_giftcard_outlined,
    'Interest': Icons.trending_up_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  static const _categoryColors = {
    'Electricity': Color(0xFF818CF8),
    'Water Bill': Color(0xFF5DCAA5),
    'Food': Color(0xFFF59E0B),
    'Transport': Color(0xFFEC4899),
    'Health': Color(0xFFF09595),
    'Shopping': Color(0xFFA855F7),
    'Education': Color(0xFF14B8A6),
    'Salary': Color(0xFF5DCAA5),
    'Freelance': Color(0xFF818CF8),
    'Business': Color(0xFFF59E0B),
    'Gift': Color(0xFFEC4899),
    'Interest': Color(0xFF14B8A6),
    'Other': Color(0xFF888780),
  };

  @override
  Widget build(BuildContext context) {
    final name = expense['name'] as String;
    final amount = (expense['amount'] as num).toDouble();
    final isPositive = amount > 0;
    final color = _categoryColors[name] ?? const Color(0xFF888780);
    final icon = _categoryIcons[name] ?? Icons.more_horiz_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFF8FAFC),
                  )),
              const SizedBox(height: 2),
              Text(expense['date'] as String,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.32),
                  )),
            ],
          ),
        ),
        Text(
          '${isPositive ? '+' : '-'} Rs. ${amount.abs().toInt()}',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isPositive
                ? const Color(0xFF5DCAA5)
                : const Color(0xFFF09595),
          ),
        ),
      ]),
    );
  }
}

// ── Empty Expenses ─────────────────────────────────────────────────────────

class _EmptyExpenses extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyExpenses({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined,
              size: 32,
              color: const Color(0xFF818CF8).withOpacity(0.4)),
          const SizedBox(height: 8),
          Text('No expenses yet',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Colors.white.withOpacity(0.35),
              )),
          const SizedBox(height: 4),
          Text('Tap to add your first expense',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: const Color(0xFF818CF8).withOpacity(0.6),
              )),
        ]),
      ),
    );
  }
}

// ── Loved Ones Card ────────────────────────────────────────────────────────

class _LovedOnesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _LovedOnesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.25)),
          color: Colors.white.withOpacity(0.03),
        ),
        child: Row(children: [
          const SizedBox(width: 20),
          Icon(Icons.location_on_outlined,
              size: 32,
              color: const Color(0xFF818CF8).withOpacity(0.7)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Find Your Loved Ones',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF8FAFC),
                  )),
              const SizedBox(height: 4),
              Text('Track family location in real time',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                  )),
            ],
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white.withOpacity(0.22)),
          const SizedBox(width: 16),
        ]),
      ),
    );
  }
}

// ── Shared Helpers ─────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
  });

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