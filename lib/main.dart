import 'package:flutter/material.dart';
import 'screens/wildfire_map_screen.dart';

void main() {
  runApp(const WildfireApp());
}

class WildfireApp extends StatelessWidget {
  const WildfireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildfire Tracker',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const WildfireMapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
