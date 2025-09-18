// lib/pages/my_places_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/places_provider.dart';
import '../models/place.dart';

class MyPlacesPage extends StatelessWidget {
  final Function(Place) onSelect;

  const MyPlacesPage({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final places = provider.places
        .where((p) => p.userId == FirebaseAuth.instance.currentUser?.uid)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('مکان‌های من')),
      body: places.isEmpty
          ? const Center(child: Text('هیچ مکانی اضافه نکرده‌اید'))
          : ListView.builder(
              itemCount: places.length,
              itemBuilder: (ctx, i) {
                final p = places[i];
                return ListTile(
                  title: Text(p.title),
                  subtitle: Text(p.category),
                  onTap: () => onSelect(p),
                );
              },
            ),
    );
  }
}
