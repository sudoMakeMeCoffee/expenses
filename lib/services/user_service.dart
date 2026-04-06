import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UserService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // ── Create user on register ────────────────────────────
 // ✅ updated — no profileType
static Future<void> createUser({
  required String userId,
  required String name,
  required String email,
}) async {
  await _db.collection('users').doc(userId).set({
    'name': name,
    'email': email,
    'avatarUrl': '',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

  // ── Get user data ──────────────────────────────────────
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  // Add these two methods to UserService class

static Future<void> updateBudget({
  required String userId,
  required double budget,
}) async {
  await _db.collection('users').doc(userId).update({
    'budget': budget,
  });
}

static Future<double> getBudget(String userId) async {
  try {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return (data?['budget'] as num?)?.toDouble() ?? 150000.0;
    }
    return 150000.0; // default budget
  } catch (e) {
    return 150000.0;
  }
}

  // ── Update name ────────────────────────────────────────
  static Future<void> updateName({
    required String userId,
    required String name,
  }) async {
    await _db.collection('users').doc(userId).update({'name': name});
  }

  // ── Upload profile photo ───────────────────────────────
  static Future<String?> uploadAvatar({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('avatars/$userId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      // Save URL to Firestore
      await _db.collection('users').doc(userId).update({
        'avatarUrl': url,
      });

      return url;
    } catch (e) {
      return null;
    }
  }
}