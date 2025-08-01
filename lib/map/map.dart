import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Optimized map widget for basic map display
/// This is a simplified version for basic map functionality
class WildfireMapPage extends StatefulWidget {
  const WildfireMapPage({super.key});

  @override
  State<WildfireMapPage> createState() => _WildfireMapPageState();
}

class _WildfireMapPageState extends State<WildfireMapPage> {
  final MapController _mapController = MapController();
  final LatLng _center = const LatLng(39.0, 35.0); // Türkiye ortası
  double _lastZoom = 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wildfire Map'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _lastZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onPositionChanged: (MapPosition pos, bool hasGesture) {
            if (hasGesture && pos.zoom != null && pos.zoom != _lastZoom) {
              setState(() {
                _lastZoom = pos.zoom!;
              });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.wildfire_map_app',
            maxZoom: 18,
            minZoom: 3,
          ),
          // Placeholder marker layer - can be extended later
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(37.7749, 32.8541), // Konya civarı
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
