import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spacepart/home.dart';
import 'package:spacepart/issuePage.dart';
import 'firebase_options.dart';

import 'search_page.dart';
const String kCurrentUserId = 'warehouseA';
const String kFromWarehouseId = 'A';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const demoWarehouseId = 'B';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warehouse Search',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(currentWarehouseId: demoWarehouseId),
    );
  }
}
