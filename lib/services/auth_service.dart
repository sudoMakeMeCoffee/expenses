import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Register ───────────────────────────────────────────
  static Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ← store user in variable so we can use uid
      final user = credential.user;
      if (user == null) return 'Registration failed';

      await user.updateDisplayName(name);

      // ── Save user profile ──────────────────────────────
      await UserService.createUser(
        userId: user.uid,
        name: name,
        email: email.trim().toLowerCase(),
      );

      // ── Auto-create default Solo account ──────────────
      // members includes owner uid so getAccounts() works for them
      await FirebaseFirestore.instance.collection('accounts').add({
        'userId': user.uid,
        'name': 'Personal',
        'type': 'Solo',
        'color': '0xFF6366F1',
        'members': [user.uid], // ← owner always in members array
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // null = success

    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code}');
      return _authError(e.code);
    } catch (e) {
      debugPrint('Unknown error: $e');
      return 'Something went wrong. Try again';
    }
  }

  // ── Login ──────────────────────────────────────────────
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code}');
      return _authError(e.code);
    }
  }

  // ── Logout ─────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Password Reset ─────────────────────────────────────
  static Future<void> sendPasswordReset({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Error messages ─────────────────────────────────────
  static String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'email-already-in-use':
        return 'Account already exists for this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Something went wrong. Try again';
    }
  }
}