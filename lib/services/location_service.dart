import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String? get _uid => _auth.currentUser?.uid;

  static StreamSubscription<Position>? _locationSubscription;

  // ── Request location permission ────────────────────────
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ── Get current position ───────────────────────────────
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('getCurrentPosition error: $e');
      return null;
    }
  }

  // ── Start sharing location ─────────────────────────────
  static Future<bool> startSharingLocation() async {
    try {
      final uid = _uid;
      if (uid == null) return false;

      final hasPermission = await requestPermission();
      if (!hasPermission) return false;

      // Set sharing flag in Firestore
      await _db.collection('userLocations').doc(uid).set({
        'uid': uid,
        'isSharing': true,
        'displayName': _auth.currentUser?.displayName ?? 'Unknown',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Start listening to position updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // update every 10 metres
        ),
      ).listen((position) async {
        try {
          await _db.collection('userLocations').doc(uid).update({
            'lat': position.latitude,
            'lng': position.longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Location update error: $e');
        }
      });

      return true;
    } catch (e) {
      debugPrint('startSharingLocation error: $e');
      return false;
    }
  }

  // ── Stop sharing location ──────────────────────────────
  static Future<void> stopSharingLocation() async {
    try {
      final uid = _uid;
      if (uid == null) return;

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      await _db.collection('userLocations').doc(uid).update({
        'isSharing': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('stopSharingLocation error: $e');
    }
  }

  // ── Check if currently sharing ─────────────────────────
  static Future<bool> isSharingLocation() async {
    try {
      final uid = _uid;
      if (uid == null) return false;

      final doc = await _db.collection('userLocations').doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['isSharing'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  // ── Send location request ──────────────────────────────
  static Future<String?> sendLocationRequest(String toEmail) async {
    try {
      final uid = _uid;
      final currentUser = _auth.currentUser;
      if (uid == null || currentUser == null) return 'Not logged in';

      // Find user by email
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: toEmail.trim().toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        // Fallback manual search
        final all = await _db.collection('users').get();
        Map<String, dynamic>? foundUser;
        for (final doc in all.docs) {
          final data = doc.data();
          final stored = (data['email'] as String? ?? '').toLowerCase();
          if (stored == toEmail.trim().toLowerCase()) {
            foundUser = {'uid': doc.id, ...data};
            break;
          }
        }
        if (foundUser == null) return 'No user found with that email';

        return await _createRequest(
          uid, currentUser, foundUser['uid'] as String, toEmail);
      }

      final toUser = query.docs.first;
      if (toUser.id == uid) return 'You cannot send a request to yourself';

      // Check if request already exists
      final existing = await _db
          .collection('locationRequests')
          .where('fromUid', isEqualTo: uid)
          .where('toUid', isEqualTo: toUser.id)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) return 'Request already sent';

      // Check if already friends
      final friendDoc = await _db
          .collection('friends')
          .doc(uid)
          .collection('list')
          .doc(toUser.id)
          .get();

      if (friendDoc.exists) return 'Already tracking this person';

      return await _createRequest(uid, currentUser, toUser.id, toEmail);
    } catch (e) {
      debugPrint('sendLocationRequest error: $e');
      return 'Failed to send request';
    }
  }

  static Future<String?> _createRequest(
    String fromUid,
    User currentUser,
    String toUid,
    String toEmail,
  ) async {
    await _db.collection('locationRequests').add({
      'fromUid': fromUid,
      'fromName': currentUser.displayName ?? 'Unknown',
      'fromEmail': currentUser.email ?? '',
      'toUid': toUid,
      'toEmail': toEmail.trim().toLowerCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null; // null = success
  }

  // ── Get incoming requests ──────────────────────────────
  static Stream<QuerySnapshot> getIncomingRequests() {
    final uid = _uid ?? '';
    return _db
        .collection('locationRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ── Get outgoing requests ──────────────────────────────
  static Stream<QuerySnapshot> getOutgoingRequests() {
    final uid = _uid ?? '';
    return _db
        .collection('locationRequests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ── Accept request ─────────────────────────────────────
  static Future<bool> acceptRequest(String requestId, String fromUid,
      String fromName) async {
    try {
      final uid = _uid;
      if (uid == null) return false;

      final batch = _db.batch();

      // Update request status
      batch.update(_db.collection('locationRequests').doc(requestId), {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Add to requester's friends list
      // (only requester can see our location)
      batch.set(
        _db.collection('friends').doc(fromUid).collection('list').doc(uid),
        {
          'friendUid': uid,
          'friendName': _auth.currentUser?.displayName ?? 'Unknown',
          'friendEmail': _auth.currentUser?.email ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('acceptRequest error: $e');
      return false;
    }
  }

  // ── Decline request ────────────────────────────────────
  static Future<bool> declineRequest(String requestId) async {
    try {
      await _db.collection('locationRequests').doc(requestId).update({
        'status': 'declined',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Get friends' locations ─────────────────────────────
  static Stream<QuerySnapshot> getFriendsList() {
    final uid = _uid ?? '';
    return _db
        .collection('friends')
        .doc(uid)
        .collection('list')
        .snapshots();
  }

  // ── Get a friend's live location ───────────────────────
  static Stream<DocumentSnapshot> getFriendLocation(String friendUid) {
    return _db.collection('userLocations').doc(friendUid).snapshots();
  }

  // ── Format last updated time ───────────────────────────
  static String formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 30) return 'Just now';
      if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }
}