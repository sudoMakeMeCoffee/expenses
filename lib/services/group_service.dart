import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; 

class GroupService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Search user by email ───────────────────────────────
  static Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
  try {
    final cleaned = email.trim().toLowerCase();

    // Try exact match first
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: cleaned)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return {'uid': doc.id, ...doc.data()};
    }

    // Fallback: search all users and compare manually
    // (handles cases where email was stored with different casing)
    final all = await _db.collection('users').get();
    for (final doc in all.docs) {
      final data = doc.data();
      final storedEmail = (data['email'] as String? ?? '').toLowerCase();
      if (storedEmail == cleaned) {
        return {'uid': doc.id, ...data};
      }
    }

    return null;
  } catch (e) {
    debugPrint('Search error: $e');
    return null;
  }
}

  // ── Create group ───────────────────────────────────────
  static Future<String?> createGroup({
    required String name,
    required List<String> memberUids,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      // Always include creator
      final members = {...memberUids, uid}.toList();

      final ref = await _db.collection('groups').add({
        'name': name,
        'createdBy': uid,
        'members': members,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      return null;
    }
  }

  // ── Get user's groups ──────────────────────────────────
  static Stream<QuerySnapshot> getUserGroups() {
    final uid = _auth.currentUser?.uid ?? '';
    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // ── Send text message ──────────────────────────────────
  static Future<bool> sendMessage({
    required String groupId,
    required String text,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final senderName = user.displayName ?? 'Unknown';
      final batch = _db.batch();

      final msgRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'senderId': user.uid,
        'senderName': senderName,
        'text': text.trim(),
        'imageUrl': null,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_db.collection('groups').doc(groupId), {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Send image message ─────────────────────────────────
  static Future<bool> sendImage({
    required String groupId,
    required File imageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Upload image
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_images')
          .child(groupId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final snapshot = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await snapshot.ref.getDownloadURL();

      final batch = _db.batch();

      final msgRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Unknown',
        'text': '',
        'imageUrl': imageUrl,
        'type': 'image',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_db.collection('groups').doc(groupId), {
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Get messages stream ────────────────────────────────
  static Stream<QuerySnapshot> getMessages(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // ── Get group members info ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getMembers(
      List<String> uids) async {
    try {
      final futures = uids.map((uid) =>
          _db.collection('users').doc(uid).get());
      final docs = await Future.wait(futures);
      return docs
          .where((d) => d.exists)
          .map((d) => {'uid': d.id, ...d.data()!})
          .toList();
    } catch (e) {
      return [];
    }
  }
}