// lib/models/place.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String title;
  final String category;
  final double lat;
  final double lng;
  final String userId;
  final bool isPublic;
  final Timestamp? createdAt;

  Place({
    required this.id,
    required this.title,
    required this.category,
    required this.lat,
    required this.lng,
    required this.userId,
    this.isPublic = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'lat': lat,
      'lng': lng,
      'userId': userId,
      'isPublic': isPublic,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Place.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Place(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      userId: data['userId'] ?? '',
      isPublic: data['isPublic'] ?? true,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
