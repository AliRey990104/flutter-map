// lib/pages/map_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../providers/places_provider.dart';
import '../models/place.dart';
import '../widgets/top_banner.dart';
import 'login_page.dart';
import 'saved_places_page.dart';
import 'recent_places_page.dart';
import 'my_places_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(29.6347, 52.5225); // شیراز پیش‌فرض
  double _zoom = 13.0;
  bool _locationLoaded = false;
  bool _isSelectingLocation = false;
  LatLng? _tempLocation;
  bool _showDirections = false;
  List<LatLng> _routePoints = [];
  String _imagePath = '';

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
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        setState(() {});
        _refreshAfterLogin();
      }
    });
  }

  Future<void> _refreshAfterLogin() async {
    if (_locationLoaded) {
      await Provider.of<PlacesProvider>(context, listen: false).fetchPlaces(
        userLocation: _currentLocation,
        radiusMeters: _radiusMeters,
        categoryFilter: _selectedCategory,
      );
      _mapController.move(_mapController.camera.center, _zoom);
    }
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

  Color _colorFromString(String s) {
    final hash = s.runes.fold<int>(0, (a, b) => a + b);
    final r = (hash * 97) % 200 + 30;
    final g = (hash * 57) % 200 + 30;
    final b = (hash * 37) % 200 + 30;
    return Color.fromARGB(255, r, g, b);
  }

  Future<String?> _pickAndSaveImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(directory.path, 'places_images'));
      await imagesDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'place_$timestamp.${path.extension(pickedFile.path)}';
      final savedImage = await File(
        pickedFile.path,
      ).copy(path.join(imagesDir.path, fileName));

      showTopBanner(
        context,
        'عکس با موفقیت ذخیره شد',
        isError: false,
        duration: const Duration(seconds: 3),
      );

      return savedImage.path;
    } catch (e) {
      showTopBanner(
        context,
        'خطا در ذخیره عکس: ${e.toString()}',
        isError: true,
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }

  Future<void> _getRoute(LatLng start, LatLng end) async {
    try {
      // استفاده از OpenStreetMap Nominatim برای geocoding (رایگان)
      final startUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${start.latitude}&lon=${start.longitude}&zoom=18&addressdetails=1',
      );
      final endUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${end.latitude}&lon=${end.longitude}&zoom=18&addressdetails=1',
      );

      final startResponse = await http.get(
        startUrl,
        headers: {'User-Agent': 'FlutterMapApp/1.0'},
      );
      final endResponse = await http.get(
        endUrl,
        headers: {'User-Agent': 'FlutterMapApp/1.0'},
      );

      if (startResponse.statusCode == 200 && endResponse.statusCode == 200) {
        // مسیر ساده - خط مستقیم (برای سادگی)
        // در حالت واقعی، از ORS API استفاده کن
        setState(() {
          _routePoints = [
            start,
            LatLng(
              (start.latitude + end.latitude) / 2,
              (start.longitude + end.longitude) / 2,
            ),
            end,
          ];
          _showDirections = true;
        });

        showTopBanner(
          context,
          'مسیر نمایش داده شد',
          isError: false,
          duration: const Duration(seconds: 3),
        );
      } else {
        showTopBanner(
          context,
          'خطا در محاسبه مسیر',
          isError: true,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      showTopBanner(
        context,
        'خطا در دریافت مسیر: ${e.toString()}',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _showDirections = false;
      _routePoints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlacesProvider>(context);
    final places = provider.places;
    final user = FirebaseAuth.instance.currentUser;
    final markers = <Marker>[];

    // مارکر موقعیت فعلی کاربر
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

    // مارکرهای مکان‌ها
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

    // مارکر قرمز برای انتخاب مکان
    if (_isSelectingLocation && _tempLocation != null) {
      markers.add(
        Marker(
          point: _tempLocation!,
          width: 40,
          height: 40,
          child: GestureDetector(
            onPanUpdate: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox == null) return;
              final offset = renderBox.globalToLocal(details.globalPosition);
              final latLng = _mapController.camera.pointToLatLng(
                math.Point<double>(offset.dx, offset.dy),
              );
              if (latLng != null) {
                setState(() {
                  _tempLocation = latLng;
                });
              }
            },
            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: _zoom,
              onTap: _isSelectingLocation
                  ? (tapPosition, point) {
                      setState(() {
                        _tempLocation = point;
                      });
                    }
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
              // مسیر دایرکشن
              if (_showDirections)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                      borderColor: Colors.blue[200]!,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
            ],
          ),

          // دکمه پاک کردن مسیر
          if (_showDirections)
            Positioned(
              top: 100,
              right: 12,
              child: FloatingActionButton(
                heroTag: 'clear_route',
                mini: true,
                backgroundColor: Colors.red,
                onPressed: _clearRoute,
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),

          // دکمه تأیید انتخاب مکان
          if (_isSelectingLocation)
            Positioned(
              bottom: 24,
              left: 12,
              child: FloatingActionButton(
                heroTag: 'confirm_location',
                onPressed: () {
                  if (_tempLocation != null) {
                    _openAddPlaceDialog(_tempLocation!);
                  }
                  setState(() {
                    _isSelectingLocation = false;
                    _tempLocation = null;
                  });
                },
                child: const Icon(Icons.check),
              ),
            ),

          // Top search bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                              hintText: 'جستجوی مکان‌ها بر اساس نام...',
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
                                  title: Text('نتایج جستجو برای "$q"'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    height: 300,
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
                                      child: const Text('بستن'),
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

                  // آواتار - اصلاح‌شده
                  GestureDetector(
                    onTap: () {
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                        return;
                      }
                    },
                    child: user == null
                        ? Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.black, Colors.grey],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "ورود / \nثبت نام",
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

          // نوار سمت چپ
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
                      tooltip: 'My Places',
                      icon: const Icon(Icons.my_location),
                      onPressed: () async {
                        await Provider.of<PlacesProvider>(
                          context,
                          listen: false,
                        ).fetchPlaces();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyPlacesPage(
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
                      onPressed: () async {
                        await Provider.of<PlacesProvider>(
                          context,
                          listen: false,
                        ).fetchRecentPlaces();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecentPlacesPage(
                              onSelect: (p) {
                                Navigator.pop(context);
                                _mapController.move(LatLng(p.lat, p.lng), 15);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // دکمه‌های کنترل
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

    final titleController = TextEditingController();
    final latController = TextEditingController(
      text: center.latitude.toString(),
    );
    final lngController = TextEditingController(
      text: center.longitude.toString(),
    );
    String? selectedCategory;
    bool isPublic = true;
    String imagePath = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اضافه کردن مکان جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'نام مکان',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'دسته‌بندی',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: categories.map((c) {
                    return DropdownMenuItem(
                      value: c['key'] as String,
                      child: Text(c['label'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Radio Button for Public/Private
                Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: isPublic,
                      onChanged: (value) {
                        setDialogState(() {
                          isPublic = value!;
                        });
                      },
                    ),
                    const Text('عمومی'),
                    Radio<bool>(
                      value: false,
                      groupValue: isPublic,
                      onChanged: (value) {
                        setDialogState(() {
                          isPublic = value!;
                        });
                      },
                    ),
                    const Text('خصوصی'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'عرض جغرافیایی (Latitude)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'طول جغرافیایی (Longitude)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // آپلود عکس
                ElevatedButton.icon(
                  onPressed: () async {
                    final imagePathSelected = await _pickAndSaveImage();
                    if (imagePathSelected != null) {
                      setDialogState(() {
                        imagePath = imagePathSelected;
                      });
                    }
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: Text(
                    'آپلود عکس ${imagePath.isNotEmpty ? '(✓)' : '(انتخاب)'}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isSelectingLocation = true;
                      _tempLocation = center;
                    });
                    showTopBanner(
                      context,
                      'مکان را با drag یا tap انتخاب کنید',
                      isError: false,
                      duration: const Duration(seconds: 3),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('انتخاب مکان روی نقشه'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    selectedCategory == null ||
                    latController.text.trim().isEmpty ||
                    lngController.text.trim().isEmpty) {
                  showTopBanner(
                    context,
                    'لطفاً تمام فیلدها را پر کنید',
                    isError: true,
                    duration: const Duration(seconds: 4),
                  );
                  return;
                }
                try {
                  final newPlace = Place(
                    id: '',
                    userId: FirebaseAuth.instance.currentUser!.uid,
                    title: titleController.text.trim(),
                    category: selectedCategory!,
                    lat: double.parse(latController.text.trim()),
                    lng: double.parse(lngController.text.trim()),
                    isPublic: isPublic,
                    imagePath: imagePath,
                  );
                  await Provider.of<PlacesProvider>(
                    context,
                    listen: false,
                  ).addPlace(newPlace);
                  Navigator.pop(context);
                  showTopBanner(
                    context,
                    'مکان با موفقیت اضافه شد',
                    isError: false,
                    duration: const Duration(seconds: 3),
                  );
                } catch (e) {
                  showTopBanner(
                    context,
                    'خطا در اضافه کردن مکان: ${e.toString()}',
                    isError: true,
                    duration: const Duration(seconds: 5),
                  );
                }
              },
              child: const Text('اضافه کردن'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceDialog(Place p) async {
    if (FirebaseAuth.instance.currentUser != null) {
      await Provider.of<PlacesProvider>(
        context,
        listen: false,
      ).addRecentPlace(p);
    }

    final provider = Provider.of<PlacesProvider>(context, listen: false);
    final distance = provider.calculateDistance(
      _currentLocation,
      LatLng(p.lat, p.lng),
    );

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxHeight: 450), // کوتاه‌تر
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title left, Creator right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.creatorEmail.isNotEmpty
                          ? p.creatorEmail.split('@')[0]
                          : 'ناشناس',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 1, color: Colors.grey),

              // Image
              if (p.imagePath.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(p.imagePath),
                    height: 140, // کوتاه‌تر
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 20, thickness: 1, color: Colors.grey),

              // Icons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.red),
                    tooltip: 'لایک',
                    onPressed: () {
                      // Placeholder for like
                      showTopBanner(
                        context,
                        'قابلیت لایک به زودی',
                        isError: false,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment, color: Colors.blue),
                    tooltip: 'نظرات',
                    onPressed: () {
                      // Placeholder for comment
                      showTopBanner(
                        context,
                        'قابلیت نظرات به زودی',
                        isError: false,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_border,
                      color: Colors.orange,
                    ),
                    tooltip: 'ذخیره',
                    onPressed: () {
                      Provider.of<PlacesProvider>(
                        context,
                        listen: false,
                      ).savePlace(p);
                      Navigator.pop(context);
                      showTopBanner(
                        context,
                        'مکان ذخیره شد',
                        isError: false,
                        duration: const Duration(seconds: 3),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions, color: Colors.green),
                    tooltip: 'مسیر',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _getRoute(_currentLocation, LatLng(p.lat, p.lng));
                    },
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 1, color: Colors.grey),

              // Bottom: Created time left, Distance right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.createdAt != null
                        ? 'ایجاد: ${p.createdAt!.day}/${p.createdAt!.month}/${p.createdAt!.year}'
                        : 'نامشخص',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
