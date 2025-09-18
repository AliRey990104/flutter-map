// lib/pages/recent_places_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/places_provider.dart';
import '../models/place.dart';

class RecentPlacesPage extends StatelessWidget {
  final Function(Place) onSelect;

  const RecentPlacesPage({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final places = provider.recentPlaces;

    return Scaffold(
      appBar: AppBar(title: const Text('مکان‌های اخیر')),
      body: places.isEmpty
          ? const Center(child: Text('هیچ مکان اخیری یافت نشد'))
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
