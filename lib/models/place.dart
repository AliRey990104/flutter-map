// lib/models/place.dart
class Place {
  final String id;
  final String userId;
  final String title;
  final String category;
  final double lat;
  final double lng;
  final bool isPublic;
  final String imagePath;
  final DateTime? createdAt;
  final String creatorEmail;

  Place({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.lat,
    required this.lng,
    this.isPublic = true,
    this.imagePath = '',
    this.createdAt,
    this.creatorEmail = '',
  });
}
