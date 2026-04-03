import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'services/account_service.dart';
import 'dart:ui' as ui;

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _purple = Color(0xFFA855F7);
  static const _bg = Color(0xFF0F1117);

  String _period = 'This Month';
  final List<String> _periods = ['This Month', '3 Months', '6 Months', 'Year'];

  List<Map<String, dynamic>> _accounts = [];
  String _selectedAccountId = '';
  String _selectedAccountName = 'All Accounts';
  bool _accountsLoading = true;

  List<Map<String, dynamic>> _expenses = [];
  bool _dataLoading = true;
  bool _pdfLoading = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  double get _totalSpent => _expenses
      .where((e) => e['type'] == 'expense')
      .fold(0.0, (s, e) => s + (e['amount'] as double));

  double get _totalIncome => _expenses
      .where((e) => e['type'] == 'income')
      .fold(0.0, (s, e) => s + (e['amount'] as double));

  double get _remaining => _totalIncome - _totalSpent;
  int get _transactionCount => _expenses.length;

  double get _avgPerDay {
    if (_expenses.isEmpty) return 0;
    final days = _periodDays();
    return days > 0 ? _totalSpent / days : 0;
  }

  int _periodDays() {
    switch (_period) {
      case '3 Months': return 90;
      case '6 Months': return 180;
      case 'Year': return 365;
      default: return DateTime.now().day;
    }
  }

  List<Map<String, dynamic>> get _categoryData {
    final Map<String, double> totals = {};
    for (final e in _expenses.where((e) => e['type'] == 'expense')) {
      final cat = e['category'] as String? ?? 'Other';
      totals[cat] = (totals[cat] ?? 0) + (e['amount'] as double);
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmt = sorted.isEmpty ? 1.0 : sorted.first.value;
    return sorted.map((e) => {
      'name': e.key,
      'amount': e.value,
      'pct': e.value / maxAmt,
      'color': _categoryColor(e.key),
      'icon': _categoryIcon(e.key),
    }).toList();
  }

  List<double> get _monthlyTrend {
    final Map<String, double> byMonth = {};
    for (final e in _expenses.where((e) => e['type'] == 'expense')) {
      final date = (e['date'] as DateTime);
      final key = DateFormat('MMM yy').format(date);
      byMonth[key] = (byMonth[key] ?? 0) + (e['amount'] as double);
    }
    if (byMonth.isEmpty) return [0];
    final sorted = byMonth.entries.toList()
      ..sort((a, b) {
        final df = DateFormat('MMM yy');
        return df.parse(a.key).compareTo(df.parse(b.key));
      });
    return sorted.map((e) => e.value).toList();
  }

  List<String> get _monthlyLabels {
    final Map<String, double> byMonth = {};
    for (final e in _expenses.where((e) => e['type'] == 'expense')) {
      final date = (e['date'] as DateTime);
      final key = DateFormat('MMM yy').format(date);
      byMonth[key] = (byMonth[key] ?? 0) + (e['amount'] as double);
    }
    if (byMonth.isEmpty) return ['—'];
    final sorted = byMonth.entries.toList()
      ..sort((a, b) {
        final df = DateFormat('MMM yy');
        return df.parse(a.key).compareTo(df.parse(b.key));
      });
    return sorted.map((e) => e.key.substring(0, 3)).toList();
  }

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
          'type': data['type'] ?? 'Solo',
        };
      }).toList();
      if (mounted) {
        setState(() { _accounts = accounts; _accountsLoading = false; });
        _loadData();
      }
    } catch (e) {
      debugPrint('loadAccounts error: $e');
      if (mounted) setState(() => _accountsLoading = false);
    }
  }

  // ── Helper to map Firestore docs ───────────────────────
  List<Map<String, dynamic>> _mapDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime date;
      try { date = (data['date'] as Timestamp).toDate(); }
      catch (_) { date = DateTime.now(); }
      return {
        'id': doc.id,
        'category': data['category'] ?? 'Other',
        'amount': (data['amount'] as num).toDouble(),
        'type': data['type'] ?? 'expense',
        'date': date,
        'note': data['note'] ?? '',
        'payerName': data['payerName'] ?? '',
        'accountId': data['accountId'] ?? '',
      };
    }).toList();
  }

  // ── Load expenses ──────────────────────────────────────
  Future<void> _loadData() async {
    if (mounted) setState(() => _dataLoading = true);
    try {
      final now = DateTime.now();
      DateTime startDate;
      switch (_period) {
        case '3 Months': startDate = DateTime(now.year, now.month - 2, 1); break;
        case '6 Months': startDate = DateTime(now.year, now.month - 5, 1); break;
        case 'Year':     startDate = DateTime(now.year, 1, 1); break;
        default:         startDate = DateTime(now.year, now.month, 1);
      }

      List<Map<String, dynamic>> expenses = [];
      final seen = <String>{};

      if (_selectedAccountId.isNotEmpty) {
        // ── Strategy 1: accountId + date filter ───────
        try {
          final s = await FirebaseFirestore.instance
              .collection('expenses')
              .where('accountId', isEqualTo: _selectedAccountId)
              .where('date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .get();
          expenses.addAll(_mapDocs(s.docs));
          debugPrint('Strategy 1 (accountId+date): ${s.docs.length} docs');
        } catch (e) {
          debugPrint('Strategy 1 failed: $e');
        }

        // ── Strategy 2: accountId only, manual date filter
        if (expenses.isEmpty) {
          try {
            final s = await FirebaseFirestore.instance
                .collection('expenses')
                .where('accountId', isEqualTo: _selectedAccountId)
                .get();
            final all = _mapDocs(s.docs);
            expenses = all
                .where((e) =>
                    (e['date'] as DateTime).isAfter(startDate))
                .toList();
            debugPrint(
                'Strategy 2 (accountId only): ${s.docs.length} total, ${expenses.length} after date filter');
          } catch (e) {
            debugPrint('Strategy 2 failed: $e');
          }
        }
      } else {
        // ── All accounts ───────────────────────────────
        final accountIds =
            _accounts.map((a) => a['id'] as String).toList();
        debugPrint('All accounts mode — accountIds: $accountIds');

        // Strategy A: per account with date
        for (final accountId in accountIds) {
          try {
            final s = await FirebaseFirestore.instance
                .collection('expenses')
                .where('accountId', isEqualTo: accountId)
                .where('date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                .get();
            for (final doc in _mapDocs(s.docs)) {
              if (seen.add(doc['id'] as String)) expenses.add(doc);
            }
            debugPrint('Account $accountId: ${s.docs.length} docs');
          } catch (e) {
            debugPrint('Account $accountId failed: $e');
          }
        }

        // Strategy B: userId fallback for older expenses
        try {
          final s = await FirebaseFirestore.instance
              .collection('expenses')
              .where('userId', isEqualTo: _myUid)
              .get();
          final all = _mapDocs(s.docs);
          final filtered = all
              .where((e) =>
                  (e['date'] as DateTime).isAfter(startDate) &&
                  seen.add(e['id'] as String))
              .toList();
          expenses.addAll(filtered);
          debugPrint(
              'Strategy B (userId): ${s.docs.length} total, ${filtered.length} new');
        } catch (e) {
          debugPrint('Strategy B failed: $e');
        }
      }

      // Sort by date descending
      expenses.sort((a, b) =>
          (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      debugPrint(
          '📊 FINAL: ${expenses.length} expenses — $_period / $_selectedAccountName');

      if (mounted) {
        setState(() { _expenses = expenses; _dataLoading = false; });
      }
    } catch (e) {
      debugPrint('loadData error: $e');
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return 'Rs. ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = v.toInt().toString();
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. ${v.toInt()}';
  }

  Future<void> _downloadPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('MMMM d, yyyy').format(now);
      final cats = _categoryData;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EXPENSE REPORT',
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo700)),
                        pw.Text('$_selectedAccountName · $_period',
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.grey600)),
                      ]),
                  pw.Text(dateStr,
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey500)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.indigo200),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (context) => [
            pw.Text('SUMMARY',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStat('Total Spent', _fmt(_totalSpent), PdfColors.red700),
                  _pdfDivider(),
                  _pdfStat('Total Income', _fmt(_totalIncome), PdfColors.green700),
                  _pdfDivider(),
                  _pdfStat('Remaining', _fmt(_remaining.abs()),
                      _remaining >= 0 ? PdfColors.green700 : PdfColors.red700),
                  _pdfDivider(),
                  _pdfStat('Transactions', '$_transactionCount', PdfColors.indigo700),
                  _pdfDivider(),
                  _pdfStat('Avg / Day', _fmt(_avgPerDay), PdfColors.grey700),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('SPENDING BY CATEGORY',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 8),
            if (cats.isEmpty)
              pw.Text('No expense data for this period.',
                  style: const pw.TextStyle(color: PdfColors.grey500))
            else
              pw.Table(
                border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                        color: PdfColors.grey200, width: 0.5)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo700),
                    children: [
                      _pdfTh('#'), _pdfTh('Category'),
                      _pdfTh('Amount'), _pdfTh('% of Total'), _pdfTh('Bar')
                    ],
                  ),
                  ...cats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    final pct = _totalSpent > 0
                        ? (cat['amount'] as double) / _totalSpent * 100
                        : 0.0;
                    final barW = (cat['pct'] as double) * 80;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: i.isEven
                              ? PdfColors.grey50
                              : PdfColors.white),
                      children: [
                        _pdfTd('${i + 1}'),
                        _pdfTd(cat['name'] as String),
                        _pdfTd(_fmt(cat['amount'] as double), bold: true),
                        _pdfTd('${pct.toStringAsFixed(1)}%'),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          child: pw.Stack(children: [
                            pw.Container(
                                height: 8,
                                width: 80,
                                decoration: pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                    borderRadius:
                                        pw.BorderRadius.circular(4))),
                            pw.Container(
                                height: 8,
                                width: barW,
                                decoration: pw.BoxDecoration(
                                    color: PdfColors.indigo400,
                                    borderRadius:
                                        pw.BorderRadius.circular(4))),
                          ]),
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo50),
                    children: [
                      _pdfTd(''),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('TOTAL',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: PdfColors.indigo700))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(_fmt(_totalSpent),
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: PdfColors.red700))),
                      _pdfTd('100%'),
                      _pdfTd(''),
                    ],
                  ),
                ],
              ),
            pw.SizedBox(height: 20),
            if (_monthlyTrend.length > 1) ...[
              pw.Text('MONTHLY TREND',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                        color: PdfColors.grey200, width: 0.5)),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo700),
                    children: [
                      _pdfTh('Month'),
                      _pdfTh('Amount Spent'),
                      _pdfTh('vs Average')
                    ],
                  ),
                  ..._monthlyTrend.asMap().entries.map((entry) {
                    final avg =
                        _monthlyTrend.reduce((a, b) => a + b) /
                            _monthlyTrend.length;
                    final diff = entry.value - avg;
                    final isAbove = diff > 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: entry.key.isEven
                              ? PdfColors.grey50
                              : PdfColors.white),
                      children: [
                        _pdfTd(entry.key < _monthlyLabels.length
                            ? _monthlyLabels[entry.key]
                            : ''),
                        _pdfTd(_fmt(entry.value), bold: true),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                '${isAbove ? '+' : ''}${_fmt(diff.abs())}',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: isAbove
                                        ? PdfColors.red600
                                        : PdfColors.green600))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Text('ALL TRANSACTIONS',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 8),
            if (_expenses.isEmpty)
              pw.Text('No transactions for this period.',
                  style: const pw.TextStyle(color: PdfColors.grey500))
            else
              pw.Table(
                border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                        color: PdfColors.grey200, width: 0.5)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo700),
                    children: [
                      _pdfTh('Date'), _pdfTh('Category'),
                      _pdfTh('Amount'), _pdfTh('Type')
                    ],
                  ),
                  ..._expenses.map((e) {
                    final isExpense = e['type'] == 'expense';
                    return pw.TableRow(children: [
                      _pdfTd(DateFormat('MMM d, yyyy')
                          .format(e['date'] as DateTime)),
                      _pdfTd(e['category'] as String),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              '${isExpense ? '-' : '+'} ${_fmt(e['amount'] as double)}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isExpense
                                      ? PdfColors.red600
                                      : PdfColors.green600))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              isExpense ? 'Expense' : 'Income',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: isExpense
                                      ? PdfColors.red400
                                      : PdfColors.green400))),
                    ]);
                  }),
                ],
              ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Expense App',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
                pw.Text(dateStr,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'expense_report_${_selectedAccountName.replaceAll(' ', '_')}_${_period.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate PDF: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) =>
      pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ]);

  pw.Widget _pdfDivider() =>
      pw.Container(width: 1, height: 30, color: PdfColors.indigo200);

  pw.Widget _pdfTh(String text) => pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)));

  pw.Widget _pdfTd(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: PdfColors.grey800)));

  Color _categoryColor(String name) {
    const colors = {
      'Food': Color(0xFFEC4899),
      'Electricity': Color(0xFF6366F1),
      'Shopping': Color(0xFFF59E0B),
      'Transport': Color(0xFF14B8A6),
      'Health': Color(0xFFA855F7),
      'Water Bill': Color(0xFF5DCAA5),
      'Education': Color(0xFF14B8A6),
      'Salary': Color(0xFF5DCAA5),
      'Freelance': Color(0xFF818CF8),
      'Business': Color(0xFFF59E0B),
      'Gift': Color(0xFFEC4899),
      'Interest': Color(0xFF14B8A6),
      'Other': Color(0xFFF09595),
    };
    return colors[name] ?? const Color(0xFF888780);
  }

  IconData _categoryIcon(String name) {
    const icons = {
      'Food': Icons.restaurant_outlined,
      'Electricity': Icons.bolt_outlined,
      'Shopping': Icons.shopping_bag_outlined,
      'Transport': Icons.directions_car_outlined,
      'Health': Icons.favorite_border_rounded,
      'Water Bill': Icons.water_drop_outlined,
      'Education': Icons.school_outlined,
      'Salary': Icons.account_balance_wallet_outlined,
      'Freelance': Icons.laptop_outlined,
      'Business': Icons.storefront_outlined,
      'Gift': Icons.card_giftcard_outlined,
      'Interest': Icons.trending_up_rounded,
      'Other': Icons.more_horiz_rounded,
    };
    return icons[name] ?? Icons.more_horiz_rounded;
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'Family': return Icons.family_restroom_rounded;
      case 'Group': return Icons.group_outlined;
      case 'Business': return Icons.business_center_outlined;
      default: return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categoryData;
    final trend = _monthlyTrend;
    final labels = _monthlyLabels;

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
                    offset: Offset(0, _slideAnim.value), child: child),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child:
                        Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('EXPENSES',
                          style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 8,
                              letterSpacing: 2.5,
                              color: _indigo.withOpacity(0.6))),
                      const Text('Analysis',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: Color(0xFFF8FAFC))),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  if (!_accountsLoading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Container(
                        height: 42,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAccountId,
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
                            items: [
                              DropdownMenuItem<String>(
                                value: '',
                                child: Row(children: [
                                  Icon(Icons.grid_view_rounded,
                                      size: 15,
                                      color: const Color(0xFF818CF8)
                                          .withOpacity(0.7)),
                                  const SizedBox(width: 8),
                                  const Text('All My Accounts',
                                      style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          color: Color(0xFFF8FAFC))),
                                ]),
                              ),
                              ..._accounts.map((acc) {
                                final type = acc['type'] as String;
                                return DropdownMenuItem<String>(
                                  value: acc['id'] as String,
                                  child: Row(children: [
                                    Icon(_accountIcon(type),
                                        size: 15,
                                        color: const Color(0xFF818CF8)
                                            .withOpacity(0.7)),
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
                              }),
                            ],
                            onChanged: (id) {
                              if (id == null) return;
                              final acc = id.isEmpty
                                  ? null
                                  : _accounts.firstWhere(
                                      (a) => a['id'] == id);
                              setState(() {
                                _selectedAccountId = id;
                                _selectedAccountName = id.isEmpty
                                    ? 'All Accounts'
                                    : acc!['name'] as String;
                              });
                              _loadData();
                            },
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _dataLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: _indigo.withOpacity(0.7),
                                strokeWidth: 2))
                        : RefreshIndicator(
                            color: _indigo,
                            backgroundColor: const Color(0xFF1A1D27),
                            onRefresh: _loadData,
                            child: SingleChildScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 24),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // ── Period filter ──────
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _periods.map((p) {
                                        final active = _period == p;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              right: 8),
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(
                                                  () => _period = p);
                                              _loadData();
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 14,
                                                  vertical: 6),
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? _indigo
                                                        .withOpacity(0.18)
                                                    : Colors.white
                                                        .withOpacity(
                                                            0.04),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20),
                                                border: Border.all(
                                                    color: active
                                                        ? _indigo
                                                            .withOpacity(
                                                                0.45)
                                                        : Colors.white
                                                            .withOpacity(
                                                                0.08)),
                                              ),
                                              child: Text(p,
                                                  style: TextStyle(
                                                      fontFamily: 'Outfit',
                                                      fontSize: 12,
                                                      color: active
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : Colors.white
                                                              .withOpacity(
                                                                  0.4))),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // ── No data ────────────
                                  if (_expenses.isEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withOpacity(0.02),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.06)),
                                      ),
                                      child: Column(children: [
                                        Icon(Icons.bar_chart_rounded,
                                            size: 40,
                                            color: Colors.white
                                                .withOpacity(0.12)),
                                        const SizedBox(height: 12),
                                        Text('No data for this period',
                                            style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14,
                                                color: Colors.white
                                                    .withOpacity(0.35))),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Try a different account or period',
                                            style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 11,
                                                color: Colors.white
                                                    .withOpacity(0.2))),
                                      ]),
                                    ),
                                  ] else ...[

                                    // ── Summary cards ──────
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 1.85,
                                      children: [
                                        _SummaryCard(
                                          label: 'Total Spent',
                                          value: _fmt(_totalSpent),
                                          sub: _totalIncome > 0
                                              ? '${(_totalSpent / _totalIncome * 100).toStringAsFixed(0)}% of income'
                                              : '$_transactionCount transactions',
                                          subColor:
                                              const Color(0xFFF09595),
                                        ),
                                        _SummaryCard(
                                          label: 'Total Income',
                                          value: _fmt(_totalIncome),
                                          valueColor:
                                              const Color(0xFF818CF8),
                                          sub: _remaining >= 0
                                              ? '${_fmt(_remaining)} left'
                                              : 'Over by ${_fmt(_remaining.abs())}',
                                          subColor: _remaining >= 0
                                              ? const Color(0xFF5DCAA5)
                                              : const Color(0xFFF09595),
                                        ),
                                        _SummaryCard(
                                          label: 'Transactions',
                                          value: '$_transactionCount',
                                          sub: '${_expenses.where((e) => e['type'] == 'expense').length} exp · ${_expenses.where((e) => e['type'] == 'income').length} inc',
                                          subColor: Colors.white
                                              .withOpacity(0.3),
                                        ),
                                        _SummaryCard(
                                          label: 'Avg / Day',
                                          value: _fmt(_avgPerDay),
                                          sub: '${_periodDays()} days tracked',
                                          subColor: Colors.white
                                              .withOpacity(0.3),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    if (cats.isNotEmpty)
                                      _Card(
                                        title: 'Category Spending',
                                        child: Column(children: [
                                          Row(children: [
                                            Expanded(
                                                child: SizedBox(
                                                    height: 100,
                                                    child: CustomPaint(
                                                        painter:
                                                            _BarChartPainter(
                                                                cats)))),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                                width: 90,
                                                height: 100,
                                                child: CustomPaint(
                                                    painter: _DonutPainter(
                                                        cats,
                                                        _fmt(_totalSpent)))),
                                          ]),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 6,
                                            children: cats
                                                .map((c) => Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                                color: c['color']
                                                                    as Color,
                                                                shape: BoxShape
                                                                    .circle)),
                                                        const SizedBox(
                                                            width: 5),
                                                        Text(
                                                            c['name']
                                                                as String,
                                                            style: TextStyle(
                                                                fontFamily:
                                                                    'Outfit',
                                                                fontSize:
                                                                    10,
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.45))),
                                                      ],
                                                    ))
                                                .toList(),
                                          ),
                                        ]),
                                      ),

                                    const SizedBox(height: 12),

                                    if (cats.isNotEmpty)
                                      _Card(
                                        title: 'Top Spending',
                                        child: Column(
                                          children: cats
                                              .take(6)
                                              .toList()
                                              .asMap()
                                              .entries
                                              .map((e) => _TopSpendingItem(
                                                    rank: e.key + 1,
                                                    category: e.value,
                                                    totalSpent: _totalSpent,
                                                  ))
                                              .toList(),
                                        ),
                                      ),

                                    const SizedBox(height: 12),

                                    if (trend.length > 1)
                                      _Card(
                                        title: 'Monthly Trend',
                                        child: SizedBox(
                                            height: 110,
                                            child: CustomPaint(
                                              size: Size.infinite,
                                              painter: _LineTrendPainter(
                                                values: trend,
                                                labels: labels,
                                                color: _indigo,
                                              ),
                                            )),
                                      ),

                                    const SizedBox(height: 12),

                                    _Card(
                                      title: 'Income vs Expense',
                                      child: Column(children: [
                                        _CompareRow(
                                            label: 'Income',
                                            value: _totalIncome,
                                            max: max(_totalIncome,
                                                _totalSpent),
                                            color:
                                                const Color(0xFF5DCAA5),
                                            formatted:
                                                _fmt(_totalIncome)),
                                        const SizedBox(height: 10),
                                        _CompareRow(
                                            label: 'Expense',
                                            value: _totalSpent,
                                            max: max(_totalIncome,
                                                _totalSpent),
                                            color:
                                                const Color(0xFFF09595),
                                            formatted: _fmt(_totalSpent)),
                                        const SizedBox(height: 10),
                                        _CompareRow(
                                            label: 'Savings',
                                            value: _remaining.abs(),
                                            max: max(_totalIncome,
                                                _totalSpent),
                                            color: _remaining >= 0
                                                ? const Color(0xFF818CF8)
                                                : const Color(0xFFF59E0B),
                                            formatted:
                                                '${_remaining >= 0 ? '+' : '-'}${_fmt(_remaining.abs())}'),
                                      ]),
                                    ),

                                    const SizedBox(height: 12),

                                    GestureDetector(
                                      onTap: _pdfLoading
                                          ? null
                                          : _downloadPdf,
                                      child: Container(
                                        width: double.infinity,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient:
                                              const LinearGradient(colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6)
                                          ]),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          boxShadow: [
                                            BoxShadow(
                                                color: _indigo
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4))
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _pdfLoading
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color:
                                                                Colors.white,
                                                            strokeWidth: 2))
                                                : const Icon(
                                                    Icons
                                                        .picture_as_pdf_rounded,
                                                    size: 18,
                                                    color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text(
                                              _pdfLoading
                                                  ? 'Generating...'
                                                  : 'Download PDF Report',
                                              style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
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
}

// ── Compare Row ────────────────────────────────────────────────────────────

class _CompareRow extends StatelessWidget {
  final String label, formatted;
  final double value, max;
  final Color color;
  const _CompareRow(
      {required this.label,
      required this.value,
      required this.max,
      required this.color,
      required this.formatted});

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.45)))),
      Expanded(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color)),
      )),
      const SizedBox(width: 10),
      SizedBox(
          width: 80,
          child: Text(formatted,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color))),
    ]);
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value, sub;
  final Color? valueColor;
  final Color subColor;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.sub,
      required this.subColor,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    letterSpacing: 0.6,
                    color: Colors.white.withOpacity(0.3))),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFFF8FAFC))),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 9, color: subColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

// ── Card ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF8FAFC))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

// ── Top Spending Item ──────────────────────────────────────────────────────

class _TopSpendingItem extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> category;
  final double totalSpent;
  const _TopSpendingItem(
      {required this.rank,
      required this.category,
      required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    final Color color = category['color'] as Color;
    final double amount = category['amount'] as double;
    final pct = totalSpent > 0 ? (amount / totalSpent * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
            width: 22,
            child: Text('#$rank',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.25)))),
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.22))),
            child: Icon(category['icon'] as IconData,
                size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(category['name'] as String,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF8FAFC))),
              const SizedBox(height: 4),
              ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: category['pct'] as double,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  )),
            ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmtDouble(amount),
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF8FAFC))),
          Text('${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9,
                  color: color.withOpacity(0.7))),
        ]),
      ]),
    );
  }

  String _fmtDouble(double v) {
    if (v >= 1000) {
      final s = v.toInt().toString();
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. ${v.toInt()}';
  }
}

// ── Bar Chart Painter ──────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  const _BarChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty) return;
    final maxAmt =
        categories.map((c) => c['amount'] as double).reduce(max);
    final barW =
        (size.width - (categories.length - 1) * 6) / categories.length;

    for (int i = 0; i < categories.length; i++) {
      final pct = (categories[i]['amount'] as double) / maxAmt;
      final barH = (size.height - 16) * pct;
      final x = i * (barW + 6);
      final y = size.height - 16 - barH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, barW, barH), const Radius.circular(4)),
        Paint()
          ..color =
              (categories[i]['color'] as Color).withOpacity(0.85)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawLine(
      Offset(0, size.height - 16),
      Offset(size.width, size.height - 16),
      Paint()
        ..color = const Color.fromRGBO(255, 255, 255, 0.08)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Donut Painter ──────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final String centerText;
  const _DonutPainter(this.categories, this.centerText);

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty) return;
    final total = categories
        .map((c) => c['amount'] as double)
        .fold(0.0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeW = 14.0;
    double startAngle = -pi / 2;

    for (final cat in categories) {
      final sweep = 2 * pi * (cat['amount'] as double) / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.08,
        false,
        Paint()
          ..color = cat['color'] as Color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweep;
    }

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFFF8FAFC),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ))
      ..addText(centerText);

    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: size.width));

    canvas.drawParagraph(
      paragraph,
      Offset(
        center.dx - paragraph.maxIntrinsicWidth / 2,
        center.dy - paragraph.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Line Trend Painter ─────────────────────────────────────────────────────

class _LineTrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  const _LineTrendPainter(
      {required this.values,
      required this.labels,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;
    final maxV = values.reduce(max);
    final minV = values.reduce(min);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;
    final chartH = size.height - 22;
    final stepX = size.width / (values.length - 1);

    List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = chartH - ((values[i] - minV) / range) * chartH * 0.82;
      points.add(Offset(x, y));
    }

    final fillPath = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath
      ..lineTo(points.last.dx, chartH)
      ..lineTo(points.first.dx, chartH)
      ..close();

    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(color.red, color.green, color.blue, 0.3),
              Color.fromRGBO(color.red, color.green, color.blue, 0.0),
            ],
          ).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color =
              Color.fromRGBO(color.red, color.green, color.blue, 0.7)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final peakIdx = values.indexOf(values.reduce(max));
    canvas.drawCircle(points[peakIdx], 4, Paint()..color = color);
    canvas.drawCircle(
        points[peakIdx],
        7,
        Paint()
          ..color = Color.fromRGBO(
              color.red, color.green, color.blue, 0.2));

    for (int i = 0; i < labels.length; i++) {
      final pb =
          ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 8))
            ..pushStyle(ui.TextStyle(
              color: const Color(0x40FFFFFF),
              fontSize: 8,
            ))
            ..addText(labels[i]);

      final p = pb.build()
        ..layout(const ui.ParagraphConstraints(width: 30));

      canvas.drawParagraph(
        p,
        Offset(i * stepX - p.maxIntrinsicWidth / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Shared Helpers ─────────────────────────────────────────────────────────

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
      left: x,
      top: y,
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [color, Colors.transparent]))));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.022)
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