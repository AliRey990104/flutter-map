// lib/providers/places_provider.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';

class PlacesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Place> _places = [];
  List<Place> get places => _places;

  List<Place> _savedPlaces = [];
  List<Place> get savedPlaces => _savedPlaces;

  bool _loading = false;
  bool get loading => _loading;

  double defaultRadiusMeters = 5000;

  Future<void> fetchPlaces({
    LatLng? userLocation,
    double? radiusMeters,
    String? categoryFilter,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('places')
          .where('isPublic', isEqualTo: true)
          .get();
      List<Place> list = snapshot.docs.map((d) => Place.fromDoc(d)).toList();

      final user = _auth.currentUser;
      if (user != null) {
        final ownSnapshot = await _firestore
            .collection('places')
            .where('userId', isEqualTo: user.uid)
            .get();
        final ownPlaces = ownSnapshot.docs
            .map((d) => Place.fromDoc(d))
            .toList();
        for (var p in ownPlaces) {
          if (!list.any((x) => x.id == p.id)) list.add(p);
        }
      }

      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        list = list.where((p) => p.category == categoryFilter).toList();
      }

      if (userLocation != null) {
        final rad = radiusMeters ?? defaultRadiusMeters;
        list = list.where((p) {
          final d = _distanceMeters(
            userLocation.latitude,
            userLocation.longitude,
            p.lat,
            p.lng,
          );
          return d <= rad;
        }).toList();
      }

      _places = list;
    } catch (e) {
      debugPrint('fetchPlaces error: $e');
      _places = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addPlace({
    required String title,
    required String category,
    required double lat,
    required double lng,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final docRef = await _firestore.collection('places').add({
      'title': title,
      'category': category,
      'lat': lat,
      'lng': lng,
      'userId': user.uid,
      'isPublic': isPublic,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final p = Place(
      id: docRef.id,
      title: title,
      category: category,
      lat: lat,
      lng: lng,
      userId: user.uid,
      isPublic: isPublic,
    );
    _places.add(p);
    notifyListeners();
  }

  Future<void> removePlace(String id) async {
    try {
      await _firestore.collection('places').doc(id).delete();
      _places.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('removePlace error: $e');
    }
  }

  // --- Saved places (per-user) ---
  Future<void> savePlace(Place p) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('not logged in');
    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPlaces')
        .doc(p.id);
    await docRef.set({
      'placeId': p.id,
      'title': p.title,
      'category': p.category,
      'lat': p.lat,
      'lng': p.lng,
      'savedAt': FieldValue.serverTimestamp(),
    });
    _savedPlaces.add(p);
    notifyListeners();
  }

  Future<void> unsavePlace(String placeId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPlaces')
        .doc(placeId)
        .delete();
    _savedPlaces.removeWhere((p) => p.id == placeId);
    notifyListeners();
  }

  Future<void> fetchSavedPlaces() async {
    final user = _auth.currentUser;
    if (user == null) {
      _savedPlaces = [];
      notifyListeners();
      return;
    }
    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPlaces')
        .orderBy('savedAt', descending: true)
        .get();
    _savedPlaces = snap.docs.map((d) {
      final data = d.data();
      return Place(
        id: d.id,
        title: data['title'] ?? '',
        category: data['category'] ?? '',
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        userId: user.uid,
      );
    }).toList();
    notifyListeners();
  }

  // helper: distance in meters (haversine)
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
}
