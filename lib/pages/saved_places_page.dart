// lib/pages/saved_places_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/places_provider.dart';

typedef OnSelectPlace = void Function(Place p);

class SavedPlacesPage extends StatelessWidget {
  final OnSelectPlace? onSelect;
  const SavedPlacesPage({super.key, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final saved = provider.savedPlaces;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Places')),
      body: saved.isEmpty
          ? const Center(child: Text('No saved places'))
          : ListView.builder(
              itemCount: saved.length,
              itemBuilder: (_, i) {
                final p = saved[i];
                return ListTile(
                  title: Text(p.title),
                  subtitle: Text(p.category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await provider.unsavePlace(p.id);
                    },
                  ),
                  onTap: () {
                    if (onSelect != null) onSelect!(p);
                  },
                );
              },
            ),
    );
  }
}
