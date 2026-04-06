import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AccountService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ── Get accounts — owned OR member of ─────────────────
  static Stream<QuerySnapshot> getAccounts() {
    final uid = _uid ?? '';
    return _db
        .collection('accounts')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  // ── Get all accessible accounts ────────────────────────
  static Stream<QuerySnapshot> getAllAccessibleAccounts() {
    final uid = _uid ?? '';
    return _db
        .collection('accounts')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  // ── Get single account ─────────────────────────────────
  static Future<Map<String, dynamic>?> getAccount(String accountId) async {
    try {
      final doc = await _db.collection('accounts').doc(accountId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('getAccount error: $e');
      return null;
    }
  }

  // ── Get account members info ───────────────────────────
  static Future<List<Map<String, dynamic>>> getAccountMembers(
      List<String> uids) async {
    try {
      final futures =
          uids.map((uid) => _db.collection('users').doc(uid).get());
      final docs = await Future.wait(futures);
      return docs
          .where((d) => d.exists)
          .map((d) => {'uid': d.id, ...d.data()!})
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Search user by email ───────────────────────────────
  static Future<Map<String, dynamic>?> searchUserByEmail(
      String email) async {
    try {
      final cleaned = email.trim().toLowerCase();

      final query = await _db
          .collection('users')
          .where('email', isEqualTo: cleaned)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return {'uid': doc.id, ...doc.data()};
      }

      // Fallback manual search
      final all = await _db.collection('users').get();
      for (final doc in all.docs) {
        final data = doc.data();
        final stored = (data['email'] as String? ?? '').toLowerCase();
        if (stored == cleaned) return {'uid': doc.id, ...data};
      }
      return null;
    } catch (e) {
      debugPrint('searchUserByEmail error: $e');
      return null;
    }
  }

  // ── Add member to account ──────────────────────────────
  static Future<bool> addMemberToAccount(
      String accountId, String memberUid) async {
    try {
      await _db.collection('accounts').doc(accountId).update({
        'members': FieldValue.arrayUnion([memberUid]),
      });
      return true;
    } catch (e) {
      debugPrint('addMemberToAccount error: $e');
      return false;
    }
  }

  // ── Remove member from account ─────────────────────────
  static Future<bool> removeMemberFromAccount(
      String accountId, String memberUid) async {
    try {
      await _db.collection('accounts').doc(accountId).update({
        'members': FieldValue.arrayRemove([memberUid]),
      });
      return true;
    } catch (e) {
      debugPrint('removeMemberFromAccount error: $e');
      return false;
    }
  }

  // ── Pending expenses ───────────────────────────────────
  static Stream<QuerySnapshot> getPendingExpenses(String accountId) {
    return _db
        .collection('accounts')
        .doc(accountId)
        .collection('pendingExpenses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<bool> submitPendingExpense({
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String payerName,
    required DateTime date,
    required String note,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _db
          .collection('accounts')
          .doc(accountId)
          .collection('pendingExpenses')
          .add({
        'submittedBy': user.uid,
        'submitterName': user.displayName ?? 'Unknown',
        'amount': amount,
        'type': type,
        'category': category,
        'payerName': payerName,
        'note': note,
        'date': Timestamp.fromDate(date),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('submitPendingExpense error: $e');
      return false;
    }
  }

  // ── Approve expense ────────────────────────────────────
  // ← KEY FIX: userId is now the ADMIN's uid (current user)
  // so the Firestore rule `userId == currentUser` passes.
  // submittedBy is stored separately to track who submitted it.
  static Future<bool> approveExpense({
    required String accountId,
    required String pendingExpenseId,
    required Map<String, dynamic> expenseData,
  }) async {
    try {
      final adminUid = _uid;
      if (adminUid == null) return false;

      final batch = _db.batch();

      final expenseRef = _db.collection('expenses').doc();
      batch.set(expenseRef, {
        // ← use adminUid as userId so rules allow the write
        'userId': adminUid,
        'accountId': accountId,
        'amount': expenseData['amount'],
        'type': expenseData['type'],
        'category': expenseData['category'],
        'payerName': expenseData['payerName'] ?? '',
        'note': expenseData['note'] ?? '',
        'date': expenseData['date'],
        'createdAt': FieldValue.serverTimestamp(),
        'approvedBy': adminUid,
        // ← keep track of who originally submitted
        'submittedBy': expenseData['submittedBy'],
      });

      final pendingRef = _db
          .collection('accounts')
          .doc(accountId)
          .collection('pendingExpenses')
          .doc(pendingExpenseId);
      batch.delete(pendingRef);

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('approveExpense error: $e');
      return false;
    }
  }

  // ── Reject expense ─────────────────────────────────────
  static Future<bool> rejectExpense({
    required String accountId,
    required String pendingExpenseId,
  }) async {
    try {
      await _db
          .collection('accounts')
          .doc(accountId)
          .collection('pendingExpenses')
          .doc(pendingExpenseId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('rejectExpense error: $e');
      return false;
    }
  }

  // ── Get account expenses stream ────────────────────────
  static Stream<QuerySnapshot> getAccountExpenses(String accountId) {
    return _db
        .collection('expenses')
        .where('accountId', isEqualTo: accountId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // ── Get account monthly expenses ───────────────────────
  static Stream<QuerySnapshot> getAccountMonthlyExpenses(
      String accountId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return _db
        .collection('expenses')
        .where('accountId', isEqualTo: accountId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date', descending: true)
        .snapshots();
  }
}