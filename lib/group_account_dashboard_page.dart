import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/account_service.dart';

class GroupAccountDashboardPage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String accountType;
  final Color accountColor;

  const GroupAccountDashboardPage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.accountColor,
  });

  @override
  State<GroupAccountDashboardPage> createState() =>
      _GroupAccountDashboardPageState();
}

class _GroupAccountDashboardPageState
    extends State<GroupAccountDashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  String _createdBy = '';
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _recentExpenses = [];
  double _totalIncome = 0;
  double _totalSpent = 0;
  bool _isLoading = true;

  // Invite member
  final _emailController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser;

  // Submit expense (non-admin)
  bool _showSubmitForm = false;
  bool _isExpenseForm = true;
  String _selectedCategory = 'Food';
  String _selectedIncomeSource = 'Salary';
  DateTime _selectedDate = DateTime.now();
  final _amountController = TextEditingController();
  final _payerController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin => _createdBy == _myUid;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Electricity', 'icon': Icons.bolt_outlined, 'color': Color(0xFF818CF8)},
    {'name': 'Water Bill', 'icon': Icons.water_drop_outlined, 'color': Color(0xFF5DCAA5)},
    {'name': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFFF59E0B)},
    {'name': 'Transport', 'icon': Icons.directions_car_outlined, 'color': Color(0xFFEC4899)},
    {'name': 'Health', 'icon': Icons.favorite_border_rounded, 'color': Color(0xFFF09595)},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined, 'color': Color(0xFFA855F7)},
    {'name': 'Education', 'icon': Icons.school_outlined, 'color': Color(0xFF14B8A6)},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Color(0xFF888780)},
  ];

  final List<Map<String, dynamic>> _incomeSources = [
    {'name': 'Salary', 'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF5DCAA5)},
    {'name': 'Freelance', 'icon': Icons.laptop_outlined, 'color': Color(0xFF818CF8)},
    {'name': 'Business', 'icon': Icons.storefront_outlined, 'color': Color(0xFFF59E0B)},
    {'name': 'Gift', 'icon': Icons.card_giftcard_outlined, 'color': Color(0xFFEC4899)},
    {'name': 'Interest', 'icon': Icons.trending_up_rounded, 'color': Color(0xFF14B8A6)},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Color(0xFF888780)},
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
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    _payerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAccountDetails(), _loadExpenses()]);
  }

  Future<void> _loadAccountDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(widget.accountId)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      _createdBy = data['userId'] as String? ?? '';
      final memberUids = List<String>.from(
          data['members'] ?? [data['userId'] ?? '']);
      final members = await AccountService.getAccountMembers(memberUids);

      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('loadAccountDetails error: $e');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final snapshot = await AccountService
          .getAccountMonthlyExpenses(widget.accountId)
          .first;

      double income = 0;
      double spent = 0;
      List<Map<String, dynamic>> expenses = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'] as String? ?? 'expense';

        if (type == 'income') {
          income += amount;
        } else {
          spent += amount;
        }

        expenses.add({
          'id': doc.id,
          'name': data['category'] ?? 'Unknown',
          'amount': type == 'expense' ? -amount : amount,
          'type': type,
          'date': _formatDate(data['date']),
          'submitterName': data['payerName'] ?? '',
          'note': data['note'] ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalSpent = spent;
          _recentExpenses = expenses.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('loadExpenses error: $e');
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
    } catch (_) {
      return '';
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return 'Rs. ${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) {
      final s = amount.toInt().toString();
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. ${amount.toInt()}';
  }

  // ── Submit expense/income (non-admin flow) ─────────────
  Future<void> _submitExpense() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnack('Please enter an amount', isError: true);
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnack('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // Admin directly saves, non-admin submits for approval
    if (_isAdmin) {
      try {
        await FirebaseFirestore.instance.collection('expenses').add({
          'userId': _myUid,
          'accountId': widget.accountId,
          'amount': amount,
          'type': _isExpenseForm ? 'expense' : 'income',
          'category': _isExpenseForm ? _selectedCategory : _selectedIncomeSource,
          'payerName': _payerController.text.trim(),
          'note': _noteController.text.trim(),
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnack('${_isExpenseForm ? 'Expense' : 'Income'} added!', isError: false);
      } catch (e) {
        _showSnack('Failed to save', isError: true);
      }
    } else {
      final success = await AccountService.submitPendingExpense(
        accountId: widget.accountId,
        amount: amount,
        type: _isExpenseForm ? 'expense' : 'income',
        category: _isExpenseForm ? _selectedCategory : _selectedIncomeSource,
        payerName: _payerController.text.trim(),
        date: _selectedDate,
        note: _noteController.text.trim(),
      );
      if (success) {
        _showSnack('Submitted for admin approval!', isError: false);
      } else {
        _showSnack('Failed to submit', isError: true);
      }
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _showSubmitForm = false;
        _amountController.clear();
        _payerController.clear();
        _noteController.clear();
        _selectedDate = DateTime.now();
        _selectedCategory = 'Food';
        _selectedIncomeSource = 'Salary';
      });
      _loadExpenses();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1D27),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Invite member ──────────────────────────────────────
  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() { _isSearching = true; _searchError = null; _foundUser = null; });
    final user = await AccountService.searchUserByEmail(email);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (user == null) { setState(() => _searchError = 'No user found with that email.'); return; }
    if (_members.any((m) => m['uid'] == user['uid'])) { setState(() => _searchError = 'Already a member.'); return; }
    setState(() { _foundUser = user; _searchError = null; });
  }

  Future<void> _addMember() async {
    if (_foundUser == null) return;
    final success = await AccountService.addMemberToAccount(
      widget.accountId, _foundUser!['uid'] as String);
    if (!mounted) return;
    if (success) {
      setState(() { _members.add(_foundUser!); _foundUser = null; _emailController.clear(); });
      _showSnack('Member added!', isError: false);
    } else {
      _showSnack('Failed to add member', isError: true);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final uid = member['uid'] as String;
    if (uid == _createdBy) { _showSnack('Cannot remove the account owner', isError: true); return; }
    final confirm = await _showConfirm(
      title: 'Remove Member',
      message: 'Remove ${member['name']} from this account?',
      confirmLabel: 'Remove',
    );
    if (!confirm) return;
    final success = await AccountService.removeMemberFromAccount(widget.accountId, uid);
    if (mounted && success) {
      setState(() => _members.removeWhere((m) => m['uid'] == uid));
      _showSnack('Member removed', isError: false);
    }
  }

  // ── Approve / Reject ───────────────────────────────────
  Future<void> _approveExpense(String pendingId, Map<String, dynamic> data) async {
    final success = await AccountService.approveExpense(
      accountId: widget.accountId,
      pendingExpenseId: pendingId,
      expenseData: data,
    );
    if (mounted) {
      _showSnack(success ? 'Expense approved!' : 'Failed to approve', isError: !success);
      if (success) _loadExpenses();
    }
  }

  Future<void> _rejectExpense(String pendingId) async {
    final success = await AccountService.rejectExpense(
      accountId: widget.accountId, pendingExpenseId: pendingId);
    if (mounted) _showSnack(success ? 'Expense rejected' : 'Failed to reject', isError: !success);
  }

  Future<bool> _showConfirm({required String title, required String message, required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC))),
        content: Text(message, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: Colors.white.withOpacity(0.4)))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE24B4A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.4)),
              ),
              child: Text(confirmLabel, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF09595))),
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
      backgroundColor: isError ? const Color(0xFF6366F1).withOpacity(0.9) : const Color(0xFF1D9E75),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _avatarColor(String name) {
    final colors = [const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFFEC4899), const Color(0xFF14B8A6), const Color(0xFFF59E0B)];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _totalIncome - _totalSpent;
    final budgetPct = _totalIncome > 0 ? (_totalSpent / _totalIncome).clamp(0.0, 1.0) : 0.0;

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
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t, size: 300, color: widget.accountColor.withOpacity(0.2)),
                _Orb(x: w - 160 - 20 * t, y: h - 260 + 26 * t, size: 220, color: _purple.withOpacity(0.12)),
              ]);
            },
          ),
          CustomPaint(size: Size.infinite, painter: _GridPainter()),

          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(offset: Offset(0, _slideAnim.value), child: child),
              ),
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: widget.accountColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: widget.accountColor.withOpacity(0.3)),
                          ),
                          child: Icon(_iconFromType(widget.accountType), size: 18, color: widget.accountColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.accountType.toUpperCase(),
                                  style: TextStyle(fontFamily: 'SpaceMono', fontSize: 8, letterSpacing: 2, color: widget.accountColor.withOpacity(0.6))),
                              Text(widget.accountName,
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC))),
                            ],
                          ),
                        ),
                        if (_isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _indigo.withOpacity(0.3)),
                            ),
                            child: const Text('Admin', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Color(0xFF818CF8))),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: _indigo.withOpacity(0.7), strokeWidth: 2))
                        : RefreshIndicator(
                            color: _indigo,
                            backgroundColor: const Color(0xFF1A1D27),
                            onRefresh: _loadAll,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Stat cards ───────
                                  Row(children: [
                                    Expanded(child: _StatCard(
                                      label: 'This Month Spent',
                                      value: _formatAmount(_totalSpent),
                                      sub: remaining >= 0 ? '▼ ${_formatAmount(remaining)} left' : '▲ Over by ${_formatAmount(remaining.abs())}',
                                      subColor: remaining >= 0 ? const Color(0xFF5DCAA5) : const Color(0xFFF09595),
                                      valueColor: const Color(0xFFF8FAFC),
                                    )),
                                    const SizedBox(width: 10),
                                    Expanded(child: _StatCard(
                                      label: 'This Month Income',
                                      value: _formatAmount(_totalIncome),
                                      sub: _totalIncome == 0 ? 'No income yet' : '${((remaining / _totalIncome) * 100).clamp(0, 100).toStringAsFixed(0)}% remaining',
                                      subColor: const Color(0xFF818CF8),
                                      valueColor: const Color(0xFF818CF8),
                                    )),
                                  ]),

                                  const SizedBox(height: 12),

                                  // ── Budget bar ────────
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: LinearProgressIndicator(
                                      value: budgetPct,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withOpacity(0.07),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        budgetPct > 0.8 ? const Color(0xFFF09595) : widget.accountColor,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // ── Add Expense/Income button ──
                                  GestureDetector(
                                    onTap: () => setState(() => _showSubmitForm = !_showSubmitForm),
                                    child: Container(
                                      width: double.infinity, height: 46,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _isExpenseForm
                                              ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                              : [const Color(0xFF0F6E56), const Color(0xFF5DCAA5)],
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                        boxShadow: [BoxShadow(
                                          color: (_isExpenseForm ? _indigo : const Color(0xFF5DCAA5)).withOpacity(0.25),
                                          blurRadius: 12, offset: const Offset(0, 4),
                                        )],
                                      ),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(_showSubmitForm ? Icons.close_rounded : Icons.add_rounded, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          _showSubmitForm
                                              ? 'Cancel'
                                              : (_isAdmin ? 'Add Expense / Income' : 'Submit for Approval'),
                                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ]),
                                    ),
                                  ),

                                  // ── Submit form ───────
                                  if (_showSubmitForm) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Non-admin notice
                                          if (!_isAdmin) ...[
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                                              ),
                                              child: Row(children: [
                                                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(
                                                  'Your submission will be sent to the admin for approval.',
                                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white.withOpacity(0.6)),
                                                )),
                                              ]),
                                            ),
                                            const SizedBox(height: 12),
                                          ],

                                          // Expense / Income toggle
                                          Row(children: [
                                            Expanded(child: GestureDetector(
                                              onTap: () => setState(() => _isExpenseForm = true),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: _isExpenseForm ? const Color(0xFFF09595).withOpacity(0.12) : Colors.white.withOpacity(0.04),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: _isExpenseForm ? const Color(0xFFF09595).withOpacity(0.4) : Colors.white.withOpacity(0.09)),
                                                ),
                                                child: Center(child: Text('▼  Expense',
                                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w500,
                                                        color: _isExpenseForm ? const Color(0xFFF09595) : Colors.white.withOpacity(0.4)))),
                                              ),
                                            )),
                                            const SizedBox(width: 10),
                                            Expanded(child: GestureDetector(
                                              onTap: () => setState(() => _isExpenseForm = false),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: !_isExpenseForm ? const Color(0xFF5DCAA5).withOpacity(0.12) : Colors.white.withOpacity(0.04),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: !_isExpenseForm ? const Color(0xFF5DCAA5).withOpacity(0.4) : Colors.white.withOpacity(0.09)),
                                                ),
                                                child: Center(child: Text('▲  Income',
                                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w500,
                                                        color: !_isExpenseForm ? const Color(0xFF5DCAA5) : Colors.white.withOpacity(0.4)))),
                                              ),
                                            )),
                                          ]),

                                          const SizedBox(height: 14),

                                          // Amount + Date row
                                          Row(children: [
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _FieldLabel('AMOUNT'),
                                                const SizedBox(height: 6),
                                                TextField(
                                                  controller: _amountController,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFF8FAFC)),
                                                  decoration: _fieldDeco(hint: '0.00',
                                                      prefix: Text('Rs.', style: TextStyle(fontFamily: 'SpaceMono', fontSize: 10, color: Colors.white.withOpacity(0.4)))),
                                                ),
                                              ],
                                            )),
                                            const SizedBox(width: 10),
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _FieldLabel('DATE'),
                                                const SizedBox(height: 6),
                                                GestureDetector(
                                                  onTap: _pickDate,
                                                  child: Container(
                                                    height: 48,
                                                    padding: const EdgeInsets.symmetric(horizontal: 13),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.04),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                                                    ),
                                                    child: Row(children: [
                                                      Expanded(child: Text(DateFormat('MMM d, yyyy').format(_selectedDate),
                                                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white.withOpacity(0.7)))),
                                                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                                                    ]),
                                                  ),
                                                ),
                                              ],
                                            )),
                                          ]),

                                          const SizedBox(height: 14),

                                          // Category / Income source grid
                                          _FieldLabel(_isExpenseForm ? 'CATEGORY' : 'INCOME SOURCE'),
                                          const SizedBox(height: 10),
                                          GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: _isExpenseForm ? 4 : 3,
                                              mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.9,
                                            ),
                                            itemCount: _isExpenseForm ? _categories.length : _incomeSources.length,
                                            itemBuilder: (_, i) {
                                              final items = _isExpenseForm ? _categories : _incomeSources;
                                              final item = items[i];
                                              final selected = _isExpenseForm
                                                  ? _selectedCategory == item['name']
                                                  : _selectedIncomeSource == item['name'];
                                              final color = item['color'] as Color;
                                              return GestureDetector(
                                                onTap: () => setState(() {
                                                  if (_isExpenseForm) _selectedCategory = item['name'] as String;
                                                  else _selectedIncomeSource = item['name'] as String;
                                                }),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  decoration: BoxDecoration(
                                                    color: selected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: selected ? color.withOpacity(0.45) : Colors.white.withOpacity(0.08), width: selected ? 1.2 : 1),
                                                  ),
                                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                    Icon(item['icon'] as IconData, size: 20, color: selected ? color : Colors.white.withOpacity(0.3)),
                                                    const SizedBox(height: 5),
                                                    Text(item['name'] as String, textAlign: TextAlign.center,
                                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 9,
                                                            color: selected ? color.withOpacity(0.9) : Colors.white.withOpacity(0.35))),
                                                  ]),
                                                ),
                                              );
                                            },
                                          ),

                                          const SizedBox(height: 14),

                                          // Payer / From field
                                          _FieldLabel(_isExpenseForm ? 'PAYER NAME' : 'RECEIVED FROM (OPTIONAL)'),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _payerController,
                                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFF8FAFC)),
                                            decoration: _fieldDeco(hint: _isExpenseForm ? 'Enter payer name' : 'e.g. Company, client...', icon: Icons.person_outline_rounded),
                                          ),

                                          const SizedBox(height: 14),

                                          // Note field
                                          _FieldLabel('NOTE (OPTIONAL)'),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _noteController,
                                            maxLines: 2,
                                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFF8FAFC)),
                                            decoration: InputDecoration(
                                              hintText: 'Add a note...',
                                              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white.withOpacity(0.25)),
                                              filled: true, fillColor: Colors.white.withOpacity(0.04),
                                              contentPadding: const EdgeInsets.all(13),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.2)),
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // Submit button
                                          GestureDetector(
                                            onTap: _isSubmitting ? null : _submitExpense,
                                            child: Container(
                                              width: double.infinity, height: 46,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                gradient: LinearGradient(
                                                  colors: _isExpenseForm
                                                      ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                                      : [const Color(0xFF0F6E56), const Color(0xFF5DCAA5)],
                                                ),
                                              ),
                                              child: Center(
                                                child: _isSubmitting
                                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                    : Text(
                                                        _isAdmin
                                                            ? 'Save ${_isExpenseForm ? 'Expense' : 'Income'}'
                                                            : 'Submit for Approval',
                                                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 20),

                                  // ── Pending approvals (admin only) ──
                                  if (_isAdmin) ...[
                                    StreamBuilder<QuerySnapshot>(
                                      stream: AccountService.getPendingExpenses(widget.accountId),
                                      builder: (context, snapshot) {
                                        final pending = snapshot.data?.docs ?? [];
                                        if (pending.isEmpty) return const SizedBox.shrink();
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              _SectionLabel('PENDING APPROVALS (${pending.length})'),
                                            ]),
                                            const SizedBox(height: 10),
                                            ...pending.map((doc) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              final amount = (data['amount'] as num).toDouble();
                                              final isExpense = (data['type'] as String? ?? 'expense') == 'expense';
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(13),
                                                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                                                ),
                                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Row(children: [
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                      Text(data['category'] as String? ?? '',
                                                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC))),
                                                      Text('by ${data['submitterName'] ?? 'Unknown'}',
                                                          style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white.withOpacity(0.4))),
                                                    ])),
                                                    Text(
                                                      '${isExpense ? '-' : '+'} ${_formatAmount(amount)}',
                                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
                                                          color: isExpense ? const Color(0xFFF09595) : const Color(0xFF5DCAA5)),
                                                    ),
                                                  ]),
                                                  if ((data['note'] as String? ?? '').isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(data['note'] as String, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white.withOpacity(0.35))),
                                                  ],
                                                  const SizedBox(height: 10),
                                                  Row(children: [
                                                    Expanded(child: GestureDetector(
                                                      onTap: () => _rejectExpense(doc.id),
                                                      child: Container(height: 34, decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.1), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.25))),
                                                          child: const Center(child: Text('Reject', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFF09595))))),
                                                    )),
                                                    const SizedBox(width: 8),
                                                    Expanded(flex: 2, child: GestureDetector(
                                                      onTap: () => _approveExpense(doc.id, data),
                                                      child: Container(height: 34, decoration: BoxDecoration(color: const Color(0xFF5DCAA5).withOpacity(0.12), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF5DCAA5).withOpacity(0.3))),
                                                          child: const Center(child: Text('Approve', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5DCAA5))))),
                                                    )),
                                                  ]),
                                                ]),
                                              );
                                            }),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      },
                                    ),
                                  ],

                                  // ── Recent transactions ─
                                  _SectionLabel('RECENT TRANSACTIONS'),
                                  const SizedBox(height: 10),
                                  _recentExpenses.isEmpty
                                      ? Container(
                                          width: double.infinity, padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withOpacity(0.06))),
                                          child: Column(children: [
                                            Icon(Icons.receipt_long_outlined, size: 28, color: Colors.white.withOpacity(0.2)),
                                            const SizedBox(height: 8),
                                            Text('No transactions yet', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white.withOpacity(0.3))),
                                          ]),
                                        )
                                      : Column(children: _recentExpenses.map((e) => _TransactionItem(expense: e)).toList()),

                                  const SizedBox(height: 20),

                                  // ── Members ───────────
                                  _SectionLabel('MEMBERS (${_members.length})'),
                                  const SizedBox(height: 10),
                                  ..._members.map((member) {
                                    final uid = member['uid'] as String;
                                    final name = member['name'] as String? ?? 'Unknown';
                                    final email = member['email'] as String? ?? '';
                                    final isOwner = uid == _createdBy;
                                    final isMe = uid == _myUid;
                                    final color = _avatarColor(name);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withOpacity(0.07))),
                                      child: Row(children: [
                                        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3))),
                                            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: color)))),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Row(children: [
                                            Text(isMe ? '$name (You)' : name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFF8FAFC))),
                                            if (isOwner) ...[
                                              const SizedBox(width: 6),
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(color: _indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _indigo.withOpacity(0.3))),
                                                  child: const Text('Admin', style: TextStyle(fontFamily: 'Outfit', fontSize: 9, color: Color(0xFF818CF8)))),
                                            ],
                                          ]),
                                          Text(email, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white.withOpacity(0.3))),
                                        ])),
                                        if (_isAdmin && !isMe && !isOwner)
                                          GestureDetector(
                                            onTap: () => _removeMember(member),
                                            child: Container(width: 30, height: 30,
                                                decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.2))),
                                                child: const Icon(Icons.person_remove_outlined, size: 14, color: Color(0xFFF09595))),
                                          ),
                                      ]),
                                    );
                                  }),

                                  const SizedBox(height: 20),

                                  // ── Invite members ────
                                  _SectionLabel('INVITE MEMBERS'),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onSubmitted: (_) => _searchUser(),
                                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFF8FAFC)),
                                      decoration: _fieldDeco(hint: 'Search by email...', icon: Icons.email_outlined),
                                    )),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _isSearching ? null : _searchUser,
                                      child: Container(width: 46, height: 46,
                                          decoration: BoxDecoration(color: _indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _indigo.withOpacity(0.35))),
                                          child: _isSearching
                                              ? Padding(padding: const EdgeInsets.all(13), child: CircularProgressIndicator(color: _indigo, strokeWidth: 2))
                                              : const Icon(Icons.person_search_outlined, color: Color(0xFF818CF8), size: 18)),
                                    ),
                                  ]),

                                  if (_searchError != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: const Color(0xFFF09595).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF09595).withOpacity(0.2))),
                                      child: Text(_searchError!, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: const Color(0xFFF09595).withOpacity(0.8))),
                                    ),
                                  ],

                                  if (_foundUser != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: const Color(0xFF5DCAA5).withOpacity(0.08), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFF5DCAA5).withOpacity(0.25))),
                                      child: Row(children: [
                                        Container(width: 36, height: 36, decoration: BoxDecoration(color: _indigo.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: _indigo.withOpacity(0.3))),
                                            child: Center(child: Text((_foundUser!['name'] as String? ?? '?').isNotEmpty ? (_foundUser!['name'] as String)[0].toUpperCase() : '?',
                                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF818CF8))))),
                                        const SizedBox(width: 10),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(_foundUser!['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFF8FAFC))),
                                          Text(_foundUser!['email'] as String? ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white.withOpacity(0.35))),
                                        ])),
                                        GestureDetector(onTap: () => setState(() => _foundUser = null),
                                            child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withOpacity(0.3))),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _addMember,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(color: const Color(0xFF5DCAA5).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF5DCAA5).withOpacity(0.35))),
                                            child: const Text('Invite', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5DCAA5))),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ],
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

  IconData _iconFromType(String type) {
    switch (type) {
      case 'Family': return Icons.family_restroom_rounded;
      case 'Group': return Icons.group_outlined;
      case 'Business': return Icons.business_center_outlined;
      default: return Icons.person_outline_rounded;
    }
  }

  InputDecoration _fieldDeco({required String hint, IconData? icon, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white.withOpacity(0.25)),
      prefixIcon: icon != null ? Icon(icon, size: 16, color: Colors.white.withOpacity(0.28)) : null,
      prefix: prefix,
      filled: true, fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.2)),
    );
  }
}

// ── Field Label ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontFamily: 'Outfit', fontSize: 10, letterSpacing: 0.9, color: Colors.white.withOpacity(0.32)));
}

// ── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor, valueColor;
  const _StatCard({required this.label, required this.value, required this.sub, required this.subColor, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.white.withOpacity(0.35))),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: valueColor)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: subColor)),
      ]),
    );
  }
}

// ── Transaction Item ───────────────────────────────────────────────────────

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> expense;
  const _TransactionItem({required this.expense});

  static const _icons = {
    'Electricity': Icons.bolt_outlined, 'Water Bill': Icons.water_drop_outlined,
    'Food': Icons.restaurant_outlined, 'Transport': Icons.directions_car_outlined,
    'Health': Icons.favorite_border_rounded, 'Shopping': Icons.shopping_bag_outlined,
    'Education': Icons.school_outlined, 'Salary': Icons.account_balance_wallet_outlined,
    'Freelance': Icons.laptop_outlined, 'Business': Icons.storefront_outlined,
    'Gift': Icons.card_giftcard_outlined, 'Interest': Icons.trending_up_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  static const _colors = {
    'Electricity': Color(0xFF818CF8), 'Water Bill': Color(0xFF5DCAA5),
    'Food': Color(0xFFF59E0B), 'Transport': Color(0xFFEC4899),
    'Health': Color(0xFFF09595), 'Shopping': Color(0xFFA855F7),
    'Education': Color(0xFF14B8A6), 'Salary': Color(0xFF5DCAA5),
    'Freelance': Color(0xFF818CF8), 'Business': Color(0xFFF59E0B),
    'Gift': Color(0xFFEC4899), 'Interest': Color(0xFF14B8A6),
    'Other': Color(0xFF888780),
  };

  @override
  Widget build(BuildContext context) {
    final name = expense['name'] as String;
    final amount = (expense['amount'] as num).toDouble();
    final isPositive = amount > 0;
    final color = _colors[name] ?? const Color(0xFF888780);
    final icon = _icons[name] ?? Icons.more_horiz_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.22))),
            child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFF8FAFC))),
          Text(expense['date'] as String, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.white.withOpacity(0.32))),
        ])),
        Text('${isPositive ? '+' : '-'} Rs. ${amount.abs().toInt()}',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: isPositive ? const Color(0xFF5DCAA5) : const Color(0xFFF09595))),
      ]),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontFamily: 'Outfit', fontSize: 10, letterSpacing: 0.9, color: Colors.white.withOpacity(0.32)));
}

// ── Shared Helpers ─────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double x, y, size;
  final Color color;
  const _Orb({required this.x, required this.y, required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Positioned(
        left: x, top: y,
        child: Container(width: size, height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent]))));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.022)..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(_) => false;
}