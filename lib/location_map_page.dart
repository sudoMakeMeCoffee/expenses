import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/location_service.dart';
import 'location_requests_page.dart';

class LocationMapPage extends StatefulWidget {
  const LocationMapPage({super.key});

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _indigo = Color(0xFF6366F1);
  static const _bg = Color(0xFF0F1117);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  bool _isSharing = false;
  bool _isLoadingShare = false;
  bool _isLoadingMap = true;

  final _emailController = TextEditingController();
  bool _isSendingRequest = false;
  String? _requestError;
  String? _requestSuccess;

  List<Map<String, dynamic>> _friends = [];
  final Map<String, StreamSubscription> _locationSubs = {};

  static const _defaultLocation = LatLng(6.9271, 79.8612); // Colombo default

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _mapController?.dispose();
    for (final sub in _locationSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _isSharing = await LocationService.isSharingLocation();
    if (mounted) setState(() {});
    _loadFriends();
  }

  // ── Load friends and subscribe to their locations ──────
  void _loadFriends() {
    LocationService.getFriendsList().listen((snapshot) async {
      final friends = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'uid': data['friendUid'] ?? doc.id,
          'name': data['friendName'] ?? 'Unknown',
          'email': data['friendEmail'] ?? '',
        };
      }).toList();

      if (mounted) setState(() => _friends = friends);

      // Subscribe to each friend's location
      for (final friend in friends) {
        final uid = friend['uid'] as String;
        if (!_locationSubs.containsKey(uid)) {
          _locationSubs[uid] =
              LocationService.getFriendLocation(uid).listen((doc) {
            if (!doc.exists || !mounted) return;
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return;

            final isSharing = data['isSharing'] as bool? ?? false;
            final lat = data['lat'] as double?;
            final lng = data['lng'] as double?;
            final name = data['displayName'] as String? ?? friend['name'];
            final lastUpdated = data['lastUpdated'];

            if (lat != null && lng != null) {
              _updateFriendMarker(
                uid: uid,
                name: name,
                lat: lat,
                lng: lng,
                isSharing: isSharing,
                lastUpdated: lastUpdated,
              );
            }
          });
        }
      }
    });
  }

  void _updateFriendMarker({
    required String uid,
    required String name,
    required double lat,
    required double lng,
    required bool isSharing,
    dynamic lastUpdated,
  }) {
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == uid);
      _markers.add(
        Marker(
          markerId: MarkerId(uid),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: isSharing
                ? '🟢 Live — ${LocationService.formatLastSeen(lastUpdated)}'
                : '⚫ Offline — ${LocationService.formatLastSeen(lastUpdated)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSharing
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueViolet,
          ),
        ),
      );
    });
  }

  // ── Toggle location sharing ────────────────────────────
  Future<void> _toggleSharing() async {
    setState(() => _isLoadingShare = true);

    if (_isSharing) {
      await LocationService.stopSharingLocation();
      if (mounted) setState(() { _isSharing = false; _isLoadingShare = false; });
    } else {
      final success = await LocationService.startSharingLocation();
      if (mounted) {
        setState(() { _isSharing = success; _isLoadingShare = false; });
        if (!success) {
          _showSnack('Location permission denied. Please enable in settings.',
              isError: true);
        }
      }
    }
  }

  // ── Send location request ──────────────────────────────
  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isSendingRequest = true;
      _requestError = null;
      _requestSuccess = null;
    });

    final error = await LocationService.sendLocationRequest(email);

    if (mounted) {
      setState(() {
        _isSendingRequest = false;
        if (error != null) {
          _requestError = error;
        } else {
          _requestSuccess = 'Request sent to $email!';
          _emailController.clear();
        }
      });
    }
  }

  // ── Center map on friend ───────────────────────────────
  void _focusFriend(String uid) {
    final marker = _markers.firstWhere(
      (m) => m.markerId.value == uid,
      orElse: () => const Marker(markerId: MarkerId('none')),
    );
    if (marker.markerId.value == 'none') {
      _showSnack('Location not available — friend may be offline', isError: true);
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: marker.position, zoom: 15),
      ),
    );
    _mapController?.showMarkerInfoWindow(marker.markerId);
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnim,
          builder: (_, child) => Opacity(opacity: _fadeAnim.value, child: child),
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: _bg,
                  border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LOCATION',
                            style: TextStyle(fontFamily: 'SpaceMono',
                                fontSize: 8, letterSpacing: 2.5,
                                color: _indigo.withOpacity(0.6))),
                        const Text('Find Loved Ones',
                            style: TextStyle(fontFamily: 'Outfit',
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: Color(0xFFF8FAFC))),
                      ],
                    ),
                  ),
                  // Requests button with badge
                  StreamBuilder<QuerySnapshot>(
                    stream: LocationService.getIncomingRequests(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const LocationRequestsPage())),
                        child: Stack(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _indigo.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                size: 18, color: Color(0xFF818CF8)),
                          ),
                          if (count > 0)
                            Positioned(
                              top: 0, right: 0,
                              child: Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF09595),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('$count',
                                      style: const TextStyle(
                                          fontFamily: 'Outfit', fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
                ]),
              ),

              // ── Map ────────────────────────────────────
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.38,
                child: Stack(children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _defaultLocation, zoom: 12),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Dark map style
                      _mapController?.setMapStyle(_darkMapStyle);
                      setState(() => _isLoadingMap = false);
                    },
                  ),
                  if (_isLoadingMap)
                    Container(
                      color: _bg,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _indigo.withOpacity(0.7), strokeWidth: 2),
                      ),
                    ),

                  // Share toggle floating button
                  Positioned(
                    bottom: 12, right: 12,
                    child: GestureDetector(
                      onTap: _isLoadingShare ? null : _toggleSharing,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSharing
                              ? const Color(0xFF5DCAA5).withOpacity(0.9)
                              : const Color(0xFF1A1D27).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isSharing
                                ? const Color(0xFF5DCAA5)
                                : Colors.white.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _isLoadingShare
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(
                                  _isSharing
                                      ? Icons.location_on_rounded
                                      : Icons.location_off_rounded,
                                  size: 16,
                                  color: _isSharing
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6)),
                          const SizedBox(width: 6),
                          Text(
                            _isSharing ? 'Sharing On' : 'Sharing Off',
                            style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isSharing
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),

                  // My location button
                  Positioned(
                    bottom: 12, left: 12,
                    child: GestureDetector(
                      onTap: () async {
                        final pos = await LocationService.getCurrentPosition();
                        if (pos != null && mounted) {
                          _mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(CameraPosition(
                              target: LatLng(pos.latitude, pos.longitude),
                              zoom: 15,
                            )),
                          );
                        }
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D27).withOpacity(0.95),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Icon(Icons.my_location_rounded,
                            size: 18, color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Bottom panel ───────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Send request ──────────────────
                      _SectionLabel('TRACK A FRIEND'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _sendRequest(),
                            style: const TextStyle(fontFamily: 'Outfit',
                                fontSize: 13, color: Color(0xFFF8FAFC)),
                            decoration: InputDecoration(
                              hintText: 'Enter friend\'s email...',
                              hintStyle: TextStyle(fontFamily: 'Outfit',
                                  fontSize: 13, color: Colors.white.withOpacity(0.25)),
                              prefixIcon: Icon(Icons.email_outlined, size: 16,
                                  color: Colors.white.withOpacity(0.28)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 13),
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
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _isSendingRequest ? null : _sendRequest,
                          child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _indigo.withOpacity(0.35)),
                            ),
                            child: _isSendingRequest
                                ? Padding(padding: const EdgeInsets.all(13),
                                    child: CircularProgressIndicator(
                                        color: _indigo, strokeWidth: 2))
                                : const Icon(Icons.send_rounded,
                                    color: Color(0xFF818CF8), size: 18),
                          ),
                        ),
                      ]),

                      // Error / success message
                      if (_requestError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF09595).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFF09595).withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 14, color: Color(0xFFF09595)),
                            const SizedBox(width: 8),
                            Text(_requestError!,
                                style: TextStyle(fontFamily: 'Outfit',
                                    fontSize: 11,
                                    color: const Color(0xFFF09595).withOpacity(0.8))),
                          ]),
                        ),
                      ],
                      if (_requestSuccess != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5DCAA5).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF5DCAA5).withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: Color(0xFF5DCAA5)),
                            const SizedBox(width: 8),
                            Text(_requestSuccess!,
                                style: const TextStyle(fontFamily: 'Outfit',
                                    fontSize: 11, color: Color(0xFF5DCAA5))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Friends list ──────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionLabel('TRACKING (${_friends.length})'),
                          if (_friends.isNotEmpty)
                            GestureDetector(
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LocationRequestsPage())),
                              child: Text('Requests →',
                                  style: TextStyle(fontFamily: 'Outfit',
                                      fontSize: 11,
                                      color: _indigo.withOpacity(0.7))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _friends.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 32,
                                    color: Colors.white.withOpacity(0.15)),
                                const SizedBox(height: 8),
                                Text('No friends tracked yet',
                                    style: TextStyle(fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.3))),
                                const SizedBox(height: 4),
                                Text('Send a request above to start',
                                    style: TextStyle(fontFamily: 'Outfit',
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.2))),
                              ]),
                            )
                          : Column(
                              children: _friends.map((friend) {
                                final uid = friend['uid'] as String;
                                final name = friend['name'] as String;

                                return StreamBuilder<DocumentSnapshot>(
                                  stream: LocationService.getFriendLocation(uid),
                                  builder: (context, snapshot) {
                                    final data = snapshot.data?.data()
                                        as Map<String, dynamic>?;
                                    final isSharing =
                                        data?['isSharing'] as bool? ?? false;
                                    final lastUpdated = data?['lastUpdated'];
                                    final hasLocation = data?['lat'] != null;

                                    return GestureDetector(
                                      onTap: () => _focusFriend(uid),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(13),
                                          border: Border.all(
                                              color: Colors.white.withOpacity(0.07)),
                                        ),
                                        child: Row(children: [
                                          // Avatar
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
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF818CF8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(name,
                                                    style: const TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: Color(0xFFF8FAFC))),
                                                Row(children: [
                                                  Container(
                                                    width: 6, height: 6,
                                                    decoration: BoxDecoration(
                                                      color: isSharing
                                                          ? const Color(0xFF5DCAA5)
                                                          : Colors.white
                                                              .withOpacity(0.3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    isSharing
                                                        ? 'Live • ${LocationService.formatLastSeen(lastUpdated)}'
                                                        : hasLocation
                                                            ? 'Offline • ${LocationService.formatLastSeen(lastUpdated)}'
                                                            : 'No location yet',
                                                    style: TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 10,
                                                        color: isSharing
                                                            ? const Color(0xFF5DCAA5)
                                                            : Colors.white
                                                                .withOpacity(0.3)),
                                                  ),
                                                ]),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            hasLocation
                                                ? Icons.location_on_rounded
                                                : Icons.location_off_rounded,
                                            size: 18,
                                            color: hasLocation
                                                ? const Color(0xFF5DCAA5)
                                                : Colors.white.withOpacity(0.2),
                                          ),
                                        ]),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontFamily: 'Outfit', fontSize: 10,
          letterSpacing: 0.9, color: Colors.white.withOpacity(0.32)));
}

// ── Dark map style ─────────────────────────────────────────────────────────

const _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1d27"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a8a9a"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1d27"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2f3e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212232"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3a3d52"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f1117"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';