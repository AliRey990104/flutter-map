import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'pages/map_page.dart';
import 'providers/places_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB5kQ_PvzmJ1v6R5oDL8nw3nmCGEXEn7po",
      appId: "1:197565807569:web:0883432f3d23bfb3313ef0",
      messagingSenderId: "197565807569",
      projectId: "city-locator-app",
      storageBucket: "city-locator-app.firebasestorage.app",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PlacesProvider())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'City Services Locator',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MapPage(),
      ),
    );
  }
}
