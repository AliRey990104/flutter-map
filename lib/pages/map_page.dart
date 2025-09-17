// lib/pages/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/places_provider.dart';
import '../models/place.dart';
import 'login_page.dart';
import 'saved_places_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(29.6347, 52.5225); // شیراز پیش‌فرض
  double _zoom = 18.0;
  bool _locationLoaded = false;

  final List<Map<String, dynamic>> categories = [
    {'key': 'pharmacy', 'label': 'Pharmacy', 'icon': Icons.local_pharmacy},
    {'key': 'atm', 'label': 'ATM', 'icon': Icons.atm},
    {'key': 'clinic', 'label': 'Clinic', 'icon': Icons.medical_services},
    {'key': 'gas', 'label': 'Gas', 'icon': Icons.local_gas_station},
  ];

  String? _selectedCategory;
  final double _radiusMeters = 5000;

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    await _tryGetLocation();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _locationLoaded) {
      await Provider.of<PlacesProvider>(context, listen: false).fetchPlaces(
        userLocation: _currentLocation,
        radiusMeters: _radiusMeters,
        categoryFilter: _selectedCategory,
      );
    } else {
      await Provider.of<PlacesProvider>(context, listen: false).fetchPlaces();
    }
  }

  Future<void> _tryGetLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _locationLoaded = true;
      });
      _mapController.move(_currentLocation, _zoom);
    } catch (e) {
      setState(() => _locationLoaded = false);
      _mapController.move(_currentLocation, _zoom);
    }
  }

  void _zoomIn() {
    setState(() {
      _zoom = (_zoom + 1).clamp(2.0, 18.0);
      _mapController.move(_mapController.camera.center, _zoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom - 1).clamp(2.0, 18.0);
      _mapController.move(_mapController.camera.center, _zoom);
    });
  }

  // رنگ رندوم از uid/email
  Color _colorFromString(String s) {
    final hash = s.runes.fold<int>(0, (a, b) => a + b);
    final r = (hash * 97) % 200 + 30;
    final g = (hash * 57) % 200 + 30;
    final b = (hash * 37) % 200 + 30;
    return Color.fromARGB(255, r, g, b);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final places = provider.places;
    final user = FirebaseAuth.instance.currentUser;
    final markers = <Marker>[];

    // small blue location marker
    markers.add(
      Marker(
        point: _currentLocation,
        width: 28,
        height: 28,
        child: Container(
          alignment: Alignment.center,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.circle, color: Colors.white, size: 8),
          ),
        ),
      ),
    );

    // places markers
    for (final p in places) {
      markers.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showPlaceDialog(p),
            child: const Icon(Icons.location_on, color: Colors.red, size: 32),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: _zoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // top search + category chips + user avatar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // search bar with constrained width
                  Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration.collapsed(
                              hintText: 'Search places by title...',
                            ),
                            onSubmitted: (q) async {
                              await provider.fetchPlaces(
                                userLocation: _currentLocation,
                                radiusMeters: _radiusMeters,
                              );
                              final filtered = provider.places
                                  .where(
                                    (pl) => pl.title.toLowerCase().contains(
                                      q.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text('Search results for "$q"'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: filtered
                                          .map(
                                            (p) => ListTile(
                                              title: Text(p.title),
                                              subtitle: Text(p.category),
                                              onTap: () {
                                                _mapController.move(
                                                  LatLng(p.lat, p.lng),
                                                  15,
                                                );
                                                Navigator.pop(context);
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // category chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((c) {
                          final key = c['key'] as String;
                          final icon = c['icon'] as IconData;
                          final label = c['label'] as String;
                          final selected = _selectedCategory == key;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              avatar: Icon(icon, size: 16),
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selected,
                              onSelected: (sel) async {
                                setState(
                                  () => _selectedCategory = sel ? key : null,
                                );
                                await provider.fetchPlaces(
                                  userLocation: user != null
                                      ? _currentLocation
                                      : null,
                                  radiusMeters: _radiusMeters,
                                  categoryFilter: _selectedCategory,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // user avatar
                  GestureDetector(
                    onTap: () {
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                        return;
                      }
                      // if logged in, maybe open profile or settings
                    },
                    child: user == null
                        ? Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.red],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "Sign\nIn/Up",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: _colorFromString(user.uid),
                            child: Text(
                              (user.email != null && user.email!.isNotEmpty)
                                  ? user.email!.substring(0, 1).toUpperCase()
                                  : (user.displayName
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        '?'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // left vertical full-height bar for logged-in users
          if (user != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 72,
                margin: const EdgeInsets.only(top: 100, bottom: 100),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Add Place',
                      icon: const Icon(Icons.add_location_alt),
                      onPressed: () {
                        _openAddPlaceDialog(_mapController.camera.center);
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: 'Saved',
                      icon: const Icon(Icons.bookmark),
                      onPressed: () async {
                        await Provider.of<PlacesProvider>(
                          context,
                          listen: false,
                        ).fetchSavedPlaces();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SavedPlacesPage(
                              onSelect: (p) {
                                Navigator.pop(context);
                                _mapController.move(LatLng(p.lat, p.lng), 15);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: 'Recent',
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recent not implemented'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // bottom-right control buttons (location, zoom in, zoom out)
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'loc',
                  mini: true,
                  onPressed: () => _mapController.move(_currentLocation, _zoom),
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zin',
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zout',
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddPlaceDialog(LatLng center) {
    if (FirebaseAuth.instance.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    // TODO: implement add place flow (dialog)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Place'),
        content: const Text('Add Place dialog not yet implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPlaceDialog(Place p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Category: ${p.category}'),
            Text('Lat: ${p.lat}, Lng: ${p.lng}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
