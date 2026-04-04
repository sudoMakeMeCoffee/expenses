import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/expense_service.dart';
import 'services/account_service.dart';
import 'create_account_page.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage>
    with TickerProviderStateMixin {
  bool _isExpense = true;
  String _selectedCategory = 'Electricity';
  String _selectedAccountId = '';
  String _selectedAccountName = '';
  DateTime _selectedDate = DateTime.now();

  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  final _payerController = TextEditingController();
  final _noteController = TextEditingController();
  final _otherCatController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _accounts = [];
  bool _accountsLoading = true;

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF8B5CF6);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Electricity', 'icon': Icons.bolt_outlined,             'color': Color(0xFF818CF8)},
    {'name': 'Water Bill',  'icon': Icons.water_drop_outlined,       'color': Color(0xFF5DCAA5)},
    {'name': 'Food',        'icon': Icons.restaurant_outlined,       'color': Color(0xFFF59E0B)},
    {'name': 'Transport',   'icon': Icons.directions_car_outlined,   'color': Color(0xFFEC4899)},
    {'name': 'Health',      'icon': Icons.favorite_border_rounded,   'color': Color(0xFFF09595)},
    {'name': 'Shopping',    'icon': Icons.shopping_bag_outlined,     'color': Color(0xFFA855F7)},
    {'name': 'Education',   'icon': Icons.school_outlined,           'color': Color(0xFF14B8A6)},
    {'name': 'Other',       'icon': Icons.more_horiz_rounded,        'color': Color(0xFF888780)},
  ];

  final List<Map<String, dynamic>> _incomeSources = [
    {'name': 'Salary',    'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF5DCAA5)},
    {'name': 'Freelance', 'icon': Icons.laptop_outlined,                 'color': Color(0xFF818CF8)},
    {'name': 'Business',  'icon': Icons.storefront_outlined,             'color': Color(0xFFF59E0B)},
    {'name': 'Gift',      'icon': Icons.card_giftcard_outlined,          'color': Color(0xFFEC4899)},
    {'name': 'Interest',  'icon': Icons.trending_up_rounded,             'color': Color(0xFF14B8A6)},
    {'name': 'Other',     'icon': Icons.more_horiz_rounded,              'color': Color(0xFF888780)},
  ];

  String _selectedIncomeSource = 'Salary';

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

    _loadAccounts();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _amountController.dispose();
    _sourceController.dispose();
    _payerController.dispose();
    _noteController.dispose();
    _otherCatController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final snapshot = await AccountService.getAccounts().first;
      final accounts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'type': data['type'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _accountsLoading = false;
          if (accounts.isNotEmpty && _selectedAccountId.isEmpty) {
            _selectedAccountId = accounts.first['id'] as String;
            _selectedAccountName = accounts.first['name'] as String;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accountsLoading = false);
        _showSnack('Failed to load accounts', isError: true);
      }
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

  Future<void> _submit() async {
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

    if (_selectedAccountId.isEmpty) {
      _showSnack('Please select an account', isError: true);
      return;
    }

    if (_isExpense && _selectedCategory == 'Other' &&
        _otherCatController.text.trim().isEmpty) {
      _showSnack('Please specify the category', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final success = await ExpenseService.addExpense(
      accountId: _selectedAccountId,
      amount: amount,
      type: _isExpense ? 'expense' : 'income',
      category: _isExpense ? _selectedCategory : _selectedIncomeSource,
      payerName: _isExpense
          ? _payerController.text.trim()
          : _sourceController.text.trim(),
      date: _selectedDate,
      note: _noteController.text.trim(),
      otherCategory: _otherCatController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _showSnack(
          '${_isExpense ? 'Expense' : 'Income'} saved successfully!',
          isError: false,
        );
        Navigator.pop(context);
      } else {
        _showSnack('Failed to save. Please try again', isError: true);
      }
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
                _Orb(x: -70 + 30 * t, y: -90 + 40 * t,
                    size: 300, color: _indigo.withOpacity(0.22)),
                _Orb(x: w - 160 - 20 * t, y: h - 260 + 26 * t,
                    size: 220, color: _purple.withOpacity(0.14)),
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
                  // ── Top bar ────────────────────────────
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
                          Text('EXPENSES',
                              style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 8,
                                letterSpacing: 2.5,
                                color: _indigo.withOpacity(0.6),
                              )),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _isExpense ? 'Add Expense' : 'Add Income',
                              key: ValueKey(_isExpense),
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Type toggle ────────────────────
                          Row(children: [
                            Expanded(
                              child: _TypeToggle(
                                label: '▼  Expense',
                                isActive: _isExpense,
                                activeColor: const Color(0xFFF09595),
                                onTap: () => setState(() => _isExpense = true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TypeToggle(
                                label: '▲  Income',
                                isActive: !_isExpense,
                                activeColor: const Color(0xFF5DCAA5),
                                onTap: () => setState(() => _isExpense = false),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // ── Amount + Date ───────────────────
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel(label: 'Amount'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}'))
                                    ],
                                    style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: Color(0xFFF8FAFC)),
                                    decoration: _fieldDeco(
                                      hint: '0.00',
                                      prefix: Text('Rs.',
                                          style: TextStyle(
                                            fontFamily: 'SpaceMono',
                                            fontSize: 10,
                                            color: Colors.white.withOpacity(0.4),
                                          )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel(label: 'Date'),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 13),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.09)),
                                      ),
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('MMM d, yyyy').format(_selectedDate),
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.calendar_today_outlined,
                                            size: 15,
                                            color: Colors.white.withOpacity(0.3)),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // ── Account dropdown ────────────────
                          _FieldLabel(label: 'Account'),
                          const SizedBox(height: 6),
                          _accountsLoading
                              ? _LoadingField()
                              : _accounts.isEmpty
                                  ? _EmptyAccountsHint(
                                      onTap: () async {
                                        final created = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CreateAccountPage(),
                                          ),
                                        );
                                        if (created == true) _loadAccounts();
                                      },
                                    )
                                  : _FirestoreAccountDropdown(
                                      accounts: _accounts,
                                      selectedId: _selectedAccountId,
                                      onChanged: (id, name) {
                                        setState(() {
                                          _selectedAccountId = id;
                                          _selectedAccountName = name;
                                        });
                                      },
                                    ),

                          const SizedBox(height: 16),

                          // ── EXPENSE FIELDS ──────────────────
                          if (_isExpense) ...[
                            _FieldLabel(label: 'Category'),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.9,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (_, i) {
                                final cat = _categories[i];
                                final isSelected = _selectedCategory == cat['name'];
                                return _CategoryChip(
                                  name: cat['name'] as String,
                                  icon: cat['icon'] as IconData,
                                  color: cat['color'] as Color,
                                  isSelected: isSelected,
                                  onTap: () => setState(
                                      () => _selectedCategory = cat['name'] as String),
                                );
                              },
                            ),

                            if (_selectedCategory == 'Other') ...[
                              const SizedBox(height: 14),
                              _FieldLabel(label: 'Specify Category'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _otherCatController,
                                style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: Color(0xFFF8FAFC)),
                                decoration: _fieldDeco(
                                  hint: 'e.g. Rent, Subscription...',
                                  icon: Icons.edit_outlined,
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            _FieldLabel(label: 'Payer Name'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _payerController,
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: Color(0xFFF8FAFC)),
                              decoration: _fieldDeco(
                                hint: 'Enter payer name',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          ],

                          // ── INCOME FIELDS ───────────────────
                          if (!_isExpense) ...[
                            _FieldLabel(label: 'Income Source'),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _incomeSources.length,
                              itemBuilder: (_, i) {
                                final src = _incomeSources[i];
                                final isSelected = _selectedIncomeSource == src['name'];
                                return _CategoryChip(
                                  name: src['name'] as String,
                                  icon: src['icon'] as IconData,
                                  color: src['color'] as Color,
                                  isSelected: isSelected,
                                  onTap: () => setState(
                                      () => _selectedIncomeSource = src['name'] as String),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            _FieldLabel(label: 'Received From (optional)'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _sourceController,
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: Color(0xFFF8FAFC)),
                              decoration: _fieldDeco(
                                hint: 'e.g. Company name, client...',
                                icon: Icons.business_outlined,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ── Note ────────────────────────────
                          _FieldLabel(label: 'Note (optional)'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _noteController,
                            maxLines: 3,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Color(0xFFF8FAFC)),
                            decoration: InputDecoration(
                              hintText: 'Add a note...',
                              hintStyle: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.25)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.all(13),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.09)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6366F1), width: 1.2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Submit button ────────────────────
                          _GradientButton(
                            label: _isExpense ? 'Add Expense' : 'Add Income',
                            isLoading: _isLoading,
                            colors: _isExpense
                                ? [_indigo, _violet, _purple]
                                : [
                                    const Color(0xFF0F6E56),
                                    const Color(0xFF1D9E75),
                                    const Color(0xFF5DCAA5),
                                  ],
                            onTap: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── NO BottomNav here — handled by MainShell ──
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco({
    required String hint,
    IconData? icon,
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 13,
          color: Colors.white.withOpacity(0.25)),
      prefixIcon: icon != null
          ? Icon(icon, size: 17, color: Colors.white.withOpacity(0.28))
          : null,
      prefix: prefix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
      ),
    );
  }
}

// ── Loading Field ──────────────────────────────────────────────────────────

class _LoadingField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Center(
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            color: const Color(0xFF6366F1).withOpacity(0.6),
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Firestore Account Dropdown ─────────────────────────────────────────────

class _FirestoreAccountDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final String selectedId;
  final void Function(String id, String name) onChanged;

  const _FirestoreAccountDropdown({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = selectedId.isEmpty ? null : selectedId;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.09), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          hint: Text('Select Account',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.25))),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.3), size: 20),
          dropdownColor: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          isExpanded: true,
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFF8FAFC)),
          items: accounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc['id'] as String,
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF818CF8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(acc['name'] as String,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                const SizedBox(width: 6),
                Text('· ${acc['type']}',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.35))),
              ]),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final acc = accounts.firstWhere((a) => a['id'] == id);
            onChanged(id, acc['name'] as String);
          },
        ),
      ),
    );
  }
}

// ── Empty Accounts Hint ────────────────────────────────────────────────────

class _EmptyAccountsHint extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyAccountsHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 16,
                color: const Color(0xFF818CF8).withOpacity(0.7)),
            const SizedBox(width: 8),
            Text('No accounts — tap to create one',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: const Color(0xFF818CF8).withOpacity(0.7),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Type Toggle ────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  const _TypeToggle({
    required this.label, required this.isActive,
    required this.activeColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : Colors.white.withOpacity(0.4),
              )),
        ),
      ),
    );
  }
}

// ── Category Chip ──────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.name, required this.icon,
    required this.color, required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.45) : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20,
                color: isSelected ? color : Colors.white.withOpacity(0.3)),
            const SizedBox(height: 5),
            Text(name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9,
                  color: isSelected
                      ? color.withOpacity(0.9)
                      : Colors.white.withOpacity(0.35),
                )),
          ],
        ),
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
    return Text(label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          letterSpacing: 0.9,
          color: Colors.white.withOpacity(0.32),
        ));
  }
}

// ── Gradient Button ────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final List<Color> colors;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label, required this.isLoading,
    required this.colors, required this.onTap,
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
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [BoxShadow(
              color: widget.colors.first.withOpacity(0.3),
              blurRadius: 18, offset: const Offset(0, 6),
            )],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(widget.label.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2, color: Colors.white,
                          )),
                    ],
                  ),
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