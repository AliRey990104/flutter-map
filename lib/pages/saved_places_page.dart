// lib/pages/saved_places_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/places_provider.dart';
import '../models/place.dart';

class SavedPlacesPage extends StatelessWidget {
  final Function(Place) onSelect;

  const SavedPlacesPage({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final places = provider.savedPlaces;

    return Scaffold(
      appBar: AppBar(title: const Text('مکان‌های ذخیره‌شده')),
      body: places.isEmpty
          ? const Center(child: Text('هیچ مکان ذخیره‌شده‌ای یافت نشد'))
          : ListView.builder(
              itemCount: places.length,
              itemBuilder: (ctx, i) {
                final p = places[i];
                return ListTile(
                  title: Text(p.title),
                  subtitle: Text(p.category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      try {
                        await provider.unsavePlace(p.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('مکان حذف شد')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در حذف: $e')),
                        );
                      }
                    },
                  ),
                  onTap: () => onSelect(p),
                );
              },
            ),
    );
  }
}
