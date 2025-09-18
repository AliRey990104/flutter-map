// lib/providers/places_provider.dart
import 'dart:math' as math; // اضافه کردن import math
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';

class PlacesProvider with ChangeNotifier {
  List<Place> _places = [];
  List<Place> _savedPlaces = [];
  List<Place> _recentPlaces = [];

  List<Place> get places => _places;
  List<Place> get savedPlaces => _savedPlaces;
  List<Place> get recentPlaces => _recentPlaces;

  Future<void> fetchPlaces({
    LatLng? userLocation,
    double radiusMeters = 5000,
    String? categoryFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'places',
      );

      if (categoryFilter != null) {
        query = query.where('category', isEqualTo: categoryFilter);
      }

      final snapshot = await query.get();
      _places = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isPublic = data['isPublic'] ?? true;
            final placeUserId = data['userId'] ?? '';

            // فیلتر private places - فقط اگر public باشه یا مال خود کاربر باشه نشون بده
            if (!isPublic &&
                currentUserId != null &&
                currentUserId != placeUserId) {
              return null; // skip private places of others
            }

            return Place(
              id: doc.id,
              userId: data['userId'] ?? '',
              title: data['title'] ?? '',
              category: data['category'] ?? '',
              lat: data['lat']?.toDouble() ?? 0.0,
              lng: data['lng']?.toDouble() ?? 0.0,
              isPublic: isPublic,
              imagePath: data['imagePath'] ?? '',
              createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
              creatorEmail: data['creatorEmail'] ?? '',
            );
          })
          .where((p) => p != null)
          .cast<Place>()
          .toList();

      if (userLocation != null) {
        _places = _places.where((place) {
          final distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            place.lat,
            place.lng,
          );
          return distance <= radiusMeters / 1000;
        }).toList();
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching places: $e');
      rethrow;
    }
  }

  Future<void> fetchSavedPlaces() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_places')
          .get();

      _savedPlaces = snapshot.docs.map((doc) {
        final data = doc.data();
        return Place(
          id: doc.id,
          userId: data['userId'] ?? '',
          title: data['title'] ?? '',
          category: data['category'] ?? '',
          lat: data['lat']?.toDouble() ?? 0.0,
          lng: data['lng']?.toDouble() ?? 0.0,
          isPublic: data['isPublic'] ?? true,
          imagePath: data['imagePath'] ?? '',
          createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
          creatorEmail: data['creatorEmail'] ?? '',
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching saved places: $e');
      rethrow;
    }
  }

  Future<void> fetchRecentPlaces() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recent_places')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _recentPlaces = snapshot.docs.map((doc) {
        final data = doc.data();
        return Place(
          id: doc.id,
          userId: data['userId'] ?? '',
          title: data['title'] ?? '',
          category: data['category'] ?? '',
          lat: data['lat']?.toDouble() ?? 0.0,
          lng: data['lng']?.toDouble() ?? 0.0,
          isPublic: data['isPublic'] ?? true,
          imagePath: data['imagePath'] ?? '',
          createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
          creatorEmail: data['creatorEmail'] ?? '',
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching recent places: $e');
      rethrow;
    }
  }

  Future<void> addRecentPlace(Place place) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recent_places')
          .doc(place.id)
          .set({
            'userId': userId,
            'title': place.title,
            'category': place.category,
            'lat': place.lat,
            'lng': place.lng,
            'isPublic': place.isPublic,
            'imagePath': place.imagePath,
            'creatorEmail': place.creatorEmail,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await fetchRecentPlaces();
    } catch (e) {
      print('Error adding recent place: $e');
      rethrow;
    }
  }

  Future<void> addPlace(Place place) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final user = await FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';

      await FirebaseFirestore.instance.collection('places').add({
        'userId': userId,
        'title': place.title,
        'category': place.category,
        'lat': place.lat,
        'lng': place.lng,
        'isPublic': place.isPublic,
        'imagePath': place.imagePath,
        'creatorEmail': email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await fetchPlaces();
    } catch (e) {
      print('Error adding place: $e');
      rethrow;
    }
  }

  Future<void> savePlace(Place place) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_places')
          .doc(place.id)
          .set({
            'userId': userId,
            'title': place.title,
            'category': place.category,
            'lat': place.lat,
            'lng': place.lng,
            'isPublic': place.isPublic,
            'imagePath': place.imagePath,
            'creatorEmail': place.creatorEmail,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await fetchSavedPlaces();
    } catch (e) {
      print('Error saving place: $e');
      rethrow;
    }
  }

  Future<void> unsavePlace(String placeId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_places')
          .doc(placeId)
          .delete();

      await fetchSavedPlaces();
    } catch (e) {
      print('Error unsaving place: $e');
      rethrow;
    }
  }

  // متد public برای محاسبه فاصله
  double calculateDistance(LatLng from, LatLng to) {
    return _calculateDistance(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);
}
