import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/favourites_store.dart';
import 'services/tfnsw_api.dart';
import 'services/vehicle_service.dart';

/// Simple app-wide singletons.
final favouritesStore = FavouritesStore();
final tfnswApi = TfnswApi();
final vehicleService = VehicleService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await favouritesStore.load();
  runApp(const NswTransitApp());
}

class NswTransitApp extends StatelessWidget {
  const NswTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF002664); // NSW Government navy
    return MaterialApp(
      title: 'NSW Transit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
